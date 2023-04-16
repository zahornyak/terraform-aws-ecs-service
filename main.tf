# service or gateway container definition creation
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
      awslogs-region        = var.region
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

  secrets = lookup(each.value, "secrets", null)

}


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
  launch_type            = var.launch_type

  network_configuration {
    subnets          = var.service_subnets
    assign_public_ip = var.assign_public_ip
    security_groups = concat([
      module.service_container_sg.security_group_id
    ], var.security_groups)
  }

  #  dynamic "load_balancer" {
  #    # if listener_arn is defined - :create load balancer association block
  #    for_each = var.lb_listener_arn != null ? [1] : []
  #    content {
  #      container_name   = var.service_name
  #      container_port   = var.lb_service_port
  #      target_group_arn = aws_lb_target_group.service[0].arn
  #    }
  #  }

  dynamic "load_balancer" {
    for_each = { for k, v in var.container_definitions : k => v if try(v.connect_to_lb, false) == true }

    content {
      target_group_arn = aws_lb_target_group.service[load_balancer.key].arn
      container_name   = load_balancer.value.container_name
      container_port   = load_balancer.value.containerPort
    }
  }


  #  dynamic "load_balancer" {q
  #    # if create_admin_endpoint true - :create load balancer association block
  #    for_each = var.create_admin_endpoint ? [1] : [0]
  #    content {
  #      container_name   = var.service_name
  #      container_port   = 9901
  #      target_group_arn = aws_lb_target_group.service_admin[0].arn
  #    }
  #  }


  #  service_registries {
  #    registry_arn = aws_service_discovery_service.service.arn
  #  }

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
  version  = "~> 3.3.0"
  for_each = { for k, v in var.container_definitions : k => v if try(v.connect_to_lb, false) == true && var.create_ssl == true }


  domain_name = "${lookup(each.value, "service_domain", null)}.${data.aws_route53_zone.this.name}"
  zone_id     = data.aws_route53_zone.this.zone_id

  wait_for_validation = true

}

resource "aws_lb_target_group" "service" {
  # if listener arn defined - create target group
  for_each = { for k, v in var.container_definitions : k => v if try(v.connect_to_lb, false) == true }

  name                 = "lb-${var.environment}-${replace(each.value.container_name, "_", "")}"
  port                 = each.value.containerPort
  protocol             = var.tg_protocol
  target_type          = var.tg_target_type
  vpc_id               = data.aws_vpc.this.id
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
      values = ["${each.value.service_domain}.${data.aws_route53_zone.this.name}"]
    }
  }
  depends_on = [aws_lb_target_group.service[0]]
}


data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_route53_zone" "this" {
  zone_id = var.route_53_zone_id
}

data "aws_lb" "this" {
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
    module.ecs_task_policy.arn,
    "arn:aws:iam::aws:policy/AWSAppMeshEnvoyAccess"
  ], var.task_role_policy_arns)

}


module "records_lb" {
  source  = "registry.terraform.io/terraform-aws-modules/route53/aws//modules/records"
  version = "~> 2.3"

  for_each = { for k, v in var.container_definitions : k => v if try(v.connect_to_lb, false) == true }

  zone_id = data.aws_route53_zone.this.id

  records = [
    {
      name = each.value.service_domain
      type = "A"
      alias = {
        name    = data.aws_lb.this.dns_name
        zone_id = data.aws_lb.this.zone_id
      }
    }
  ]

}


module "service_container_sg" {
  source  = "registry.terraform.io/terraform-aws-modules/security-group/aws"
  version = "~> 4.3"

  name        = "${var.environment}-service-container-sg"
  description = "Security group for ${var.environment} backend Container"
  vpc_id      = var.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = var.lb_service_port
      to_port     = var.lb_service_port
      protocol    = "tcp"
      description = "${var.service_name} service port"
      cidr_blocks = data.aws_vpc.this.cidr_block
  }]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]


}



