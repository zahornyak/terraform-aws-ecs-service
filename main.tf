# service container definition creation
module "service_container_definition" {
  for_each = var.container_definitions

  source  = "registry.terraform.io/cloudposse/ecs-container-definition/aws"
  version = "~> 0.58"

  container_image = lookup(each.value, "container_image", null)
  container_name  = lookup(each.value, "container_name", null)
  essential       = lookup(each.value, "essential", true)

  #  container_definition = var.container_definition

  container_cpu    = lookup(each.value, "container_cpu", null)
  container_memory = lookup(each.value, "container_memory", null)

  stop_timeout = lookup(each.value, "stop_timeout", 5)
  log_configuration = lookup(each.value, "log_configuration", null) != null ? lookup(each.value, "log_configuration", null) : {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.service_logs[each.key].name
      awslogs-region        = data.aws_region.current.name
      awslogs-stream-prefix = lookup(each.value, "container_name", null)
    }
  }

  # docker healthcheck
  healthcheck = lookup(each.value, "healthcheck", null)

  container_depends_on = lookup(each.value, "container_depends_on", null)

  port_mappings = lookup(each.value, "port_mappings", null) != null ? lookup(each.value, "port_mappings", null) : [
    {
      containerPort = lookup(each.value, "containerPort", null)
      protocol      = lookup(each.value, "protocol", "tcp")
      hostPort      = lookup(each.value, "hostPort", null)
    }
  ]

  environment_files = lookup(each.value, "environment_files", null)
  environment       = lookup(each.value, "environment", null)

  secrets = lookup(each.value, "ssm_secrets", null) != null || lookup(each.value, "ssm_env_file", null) != null ? [
    for k, v in module.env_variables[each.key].parameters_arns : {
      name      = k
      valueFrom = v
    }
  ] : lookup(each.value, "secrets", null)

}

#locals {
#  container_def_keys = keys(var.container_definitions)
#  env_ssm_vars = [
#    for k, v in module.env_variables.parameters_arns : {
#      name      = k
#      valueFrom = v
#    }
#  ]
#}


data "aws_region" "current" {}

# task definition for service
resource "aws_ecs_task_definition" "service" {
  family                   = "${var.environment}_${var.service_name}_task"
  container_definitions    = jsonencode(values(module.service_container_definition)[*].json_map_object)
  cpu                      = var.service_cpu
  memory                   = var.service_memory
  requires_compatibilities = var.requires_compatibilities
  network_mode             = var.network_mode
  execution_role_arn       = module.ecs_task_execution_role.iam_role_arn
  task_role_arn            = module.ecs_task_role.iam_role_arn
}

# service creation
resource "aws_ecs_service" "service" {
  name                   = "${var.environment}_${var.service_name}_service"
  task_definition        = aws_ecs_task_definition.service.arn
  desired_count          = var.desired_count != null ? var.desired_count : var.min_service_tasks
  cluster                = var.cluster_name
  enable_execute_command = true
  launch_type            = var.capacity_provider_strategy == null ? var.launch_type : null

  # add service discovery connection TODO

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy
    content {
      capacity_provider = try(capacity_provider_strategy.value.capacity_provider, "FARGATE_SPOT")
      base              = try(capacity_provider_strategy.value.base, 1)
      weight            = try(capacity_provider_strategy.value.weight, 1)
    }
  }


  dynamic "ordered_placement_strategy" {
    for_each = var.ordered_placement_strategy
    content {
      type  = try(ordered_placement_strategy.value.type, null)
      field = try(ordered_placement_strategy.value.field, null)
    }
  }

  dynamic "placement_constraints" {
    for_each = var.placement_constraints
    content {
      type       = try(placement_constraints.value.type, null)
      expression = try(placement_constraints.value.expression, null)
    }
  }




  network_configuration {
    subnets          = var.service_subnets
    assign_public_ip = var.assign_public_ip
    security_groups = concat(
      values(module.service_container_sg)[*].security_group_id
    , var.security_groups)
  }

  dynamic "load_balancer" {
    for_each = { for k, v in var.container_definitions : k => v if try(v.connect_to_lb, false) == true }

    content {
      target_group_arn = aws_lb_target_group.service[load_balancer.key].arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.containerPort
    }
  }



  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  # thats only if you have lb connection on service
  health_check_grace_period_seconds = var.lb_listener_arn != null ? var.health_check_grace_period_seconds : null

}

resource "aws_cloudwatch_log_group" "service_logs" {
  for_each = { for k, v in var.container_definitions : k => v if try(v.log_configuration, "") == "" }

  name              = "${var.environment}-${lookup(each.value, "container_name", null)}-logs"
  retention_in_days = var.retention_in_days
}

resource "aws_lb_listener_certificate" "this" {
  for_each = { for k, v in var.container_definitions : k => v if try(v.connect_to_lb, false) == true && var.create_ssl == true }

  listener_arn    = var.lb_listener_arn
  certificate_arn = module.acm[each.key].acm_certificate_arn
}

module "acm" {
  source   = "terraform-aws-modules/acm/aws"
  version  = "~> 3.3"
  for_each = { for k, v in var.container_definitions : k => v if try(v.connect_to_lb, false) == true && var.create_ssl == true }


  domain_name = "${lookup(each.value, "service_domain", null)}.${var.route_53_zone_name == null ? data.aws_route53_zone.this[0].name : var.route_53_zone_name}"
  zone_id     = var.route_53_zone_id

  wait_for_validation = true

}

resource "aws_lb_target_group" "service" {
  # if listener arn defined - create target group
  for_each = { for k, v in var.container_definitions : k => v if try(v.connect_to_lb, false) == true }

  name                 = "lb-${var.environment}-${replace(each.value.container_name, "_", "")}"
  port                 = each.value.containerPort
  protocol             = var.tg_protocol
  target_type          = var.tg_target_type
  vpc_id               = var.vpc_id
  deregistration_delay = var.deregistration_delay
  health_check {
    enabled             = try(var.health_check.enabled, null)
    interval            = try(var.health_check.interval, null)
    path                = try(var.health_check.path, null)
    timeout             = try(var.health_check.timeout, null)
    healthy_threshold   = try(var.health_check.healthy_threshold, null)
    unhealthy_threshold = try(var.health_check.unhealthy_threshold, null)
    matcher             = try(var.health_check.matcher, null)
  }
}

resource "aws_lb_listener_rule" "service" {

  for_each = { for k, v in var.container_definitions : k => v if try(v.connect_to_lb, false) == true }


  listener_arn = var.lb_listener_arn

  action {
    type = "forward"
    # if custom target group is not defined - route to service target group
    target_group_arn = aws_lb_target_group.service[each.key].arn
  }

  condition {
    host_header {
      values = ["${each.value.service_domain}.${var.route_53_zone_name == null ? data.aws_route53_zone.this[0].name : var.route_53_zone_name}"]
    }
  }
  depends_on = [aws_lb_target_group.service[0]]
}


data "aws_vpc" "this" {
  count = var.vpc_id != null ? 1 : 0
  id    = var.vpc_id
}

data "aws_route53_zone" "this" {
  count   = var.route_53_zone_id != null ? 1 : 0
  zone_id = var.route_53_zone_id
}

data "aws_lb" "this" {
  for_each = { for k, v in var.container_definitions : k => v if try(v.lb_arn, null) != null }
  #  count = try(var.lb_arn != null ? 1 : 0, 0)
  arn = var.lb_arn
}


module "ecs_task_execution_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 4.4"

  trusted_role_services = [
    "ecs-tasks.amazonaws.com"
  ]

  create_role = true

  role_name         = "${var.environment}-${var.service_name}EcsTaskExecutionRole"
  role_requires_mfa = false


  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
  ]
}

module "ecs_task_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "~> 4.4"

  name = "${var.environment}-${var.service_name}EcsTaskPolicy"

  policy = data.aws_iam_policy_document.ecs_task_policy.json
}


data "aws_iam_policy_document" "ecs_task_policy" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }
  #  statement {
  #    actions = [
  #      "appmesh:*"
  #    ]
  #    resources = ["*"]
  #  }
}


module "ecs_task_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 4.4"

  trusted_role_services = [
    "ecs-tasks.amazonaws.com"
  ]

  create_role = true

  role_name         = "${var.environment}-${var.service_name}EcsTaskRole"
  role_requires_mfa = false


  custom_role_policy_arns = concat([
    module.ecs_task_policy.arn
  ], var.task_role_policy_arns)

}


module "records_lb" {
  source  = "registry.terraform.io/terraform-aws-modules/route53/aws//modules/records"
  version = "~> 2.3"

  for_each = { for k, v in var.container_definitions : k => v if try(v.connect_to_lb, false) == true }

  zone_id = var.route_53_zone_id

  records = [
    {
      name = each.value.service_domain
      type = "A"
      alias = {
        name    = var.lb_dns_name == null ? data.aws_lb.this[0].dns_name : var.lb_dns_name
        zone_id = var.route_53_zone_id
      }
    }
  ]

}


module "service_container_sg" {
  source  = "registry.terraform.io/terraform-aws-modules/security-group/aws"
  version = "~> 4.3"

  for_each = { for k, v in var.container_definitions : k => v }


  name        = "${var.environment}-service-${each.value.container_name}-container-sg"
  description = "Security group for ${var.environment} ${each.value.container_name} Container"
  vpc_id      = var.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = each.value.containerPort
      to_port     = each.value.containerPort
      protocol    = "tcp"
      description = "${var.service_name} ${each.value.container_name} container service port"
      cidr_blocks = var.vpc_cidr_block == null ? data.aws_vpc.this[0].cidr_block : var.vpc_cidr_block
  }]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

}

# add autoscaling TODO
resource "aws_appautoscaling_target" "service_scaling" {
  count = var.max_service_tasks != null || var.max_service_tasks != null || var.cpu_scaling_target_value != null || var.cpu_scale_in_cooldown != null || var.cpu_scale_out_cooldown != null || var.memory_scaling_target_value != null || var.memory_scale_in_cooldown != null || var.memory_scale_out_cooldown != null ? 1 : 0

  max_capacity       = var.max_service_tasks
  min_capacity       = var.min_service_tasks
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "target_tracking_scaling_cpu_service" {
  count = var.max_service_tasks == null && var.max_service_tasks == null && var.cpu_scaling_target_value == null && var.cpu_scale_in_cooldown == null && var.cpu_scale_out_cooldown == null || var.cpu_scaling == false ? 0 : 1

  name               = "TargetTrackingScaling_cpu_${var.environment}_${var.service_name}_service"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_scaling[0].resource_id
  scalable_dimension = aws_appautoscaling_target.service_scaling[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_scaling[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.cpu_scaling_target_value
    scale_in_cooldown  = var.cpu_scale_in_cooldown
    scale_out_cooldown = var.cpu_scale_out_cooldown
  }
}

resource "aws_appautoscaling_policy" "target_tracking_scaling_memory_service" {
  count = var.max_service_tasks == null && var.memory_scaling_target_value == null && var.memory_scale_in_cooldown == null && var.memory_scale_out_cooldown == null || var.memory_scaling == false ? 0 : 1

  name               = "TargetTrackingScaling_memory_${var.environment}_${var.service_name}_service"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.service_scaling[0].resource_id
  scalable_dimension = aws_appautoscaling_target.service_scaling[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.service_scaling[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = var.memory_scaling_target_value
    scale_in_cooldown  = var.memory_scale_in_cooldown
    scale_out_cooldown = var.memory_scale_out_cooldown

    disable_scale_in = true
  }
}

## SSM
#locals {
#  env_ssm_vars = { for k, v in var.container_definitions : k => v if try(v.ssm_secrets, null) != null || try(v.ssm_env_file, null) != null } != {} ? [
#    for k, v in module.env_variables.parameters_arns : {
#      name      = k
#      valueFrom = v
#    }
#  ] : null
#}

module "env_variables" {
  source  = "zahornyak/multiple-ssm-parameters/aws"
  version = "0.0.9"

  for_each = { for k, v in var.container_definitions : k => v if try(v.ssm_secrets, null) != null || try(v.ssm_env_file, null) != null }

  parameter_prefix = var.parameter_prefix != null ? var.parameter_prefix : "/${var.environment}/${var.service_name}/${lookup(each.value, "container_name", null)}/"

  parameters = lookup(each.value, "ssm_secrets", {})

  file_path = lookup(each.value, "ssm_env_file", null)
}



