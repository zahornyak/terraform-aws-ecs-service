# service or gateway container definition creation
module "service_container_definition" {
  source          = "registry.terraform.io/cloudposse/ecs-container-definition/aws"
  version         = "~> 0.58"
  container_image = var.service_image_tag
  container_name  = var.service_name
  essential       = true

  container_definition = var.container_definition

  container_cpu    = var.service_cpu
  container_memory = var.service_memory

  stop_timeout = 5
  log_configuration = var.log_configuration != null ? var.log_configuration : {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.service_logs.name
      awslogs-region        = var.region
      awslogs-stream-prefix = var.service_name
    }
  }

  # docker healthcheck
  healthcheck = var.docker_healthcheck

  #  container_depends_on = var.create_envoy ? var.envoy_dependency : null

  port_mappings = var.port_mapping != null ? var.port_mapping : [
    {
      containerPort = var.service_port
      protocol      = "tcp"
      hostPort      = null
    }
  ]

  environment_files = var.environment_files
  environment       = var.environment_vars

  secrets = var.secrets
}


# task definition for service
resource "aws_ecs_task_definition" "service" {
  family                   = "${var.environment}_${var.service_name}_task"
  container_definitions    = module.service_container_definition.json_map_encoded_list
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
    security_groups  = [module.service_container_sg.security_group_id]
  }

  dynamic "load_balancer" {
    # if listener_arn is defined - :create load balancer association block
    for_each = var.alb_listener_arn != null ? [1] : []
    content {
      container_name   = var.service_name
      container_port   = var.service_port
      target_group_arn = aws_lb_target_group.service[0].arn
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
  # thats only if you have alb connection on service
  health_check_grace_period_seconds = var.alb_listener_arn != null ? var.health_check_grace_period_seconds : null

}

resource "aws_cloudwatch_log_group" "service_logs" {
  name              = "${var.environment}-${var.service_name}-logs"
  retention_in_days = 60
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 3.3.0"
  count   = var.create_ssl ? 1 : 0

  domain_name = "${var.service_domain}.${data.aws_route53_zone.this.name}"
  zone_id     = data.aws_route53_zone.this.zone_id

  wait_for_validation = true

}

resource "aws_lb_listener_certificate" "this" {
  count = var.create_ssl ? 1 : 0

  listener_arn    = var.alb_listener_arn
  certificate_arn = module.acm[0].acm_certificate_arn
}

resource "aws_lb_target_group" "service" {
  # if listener arn defined - create target group
  count = var.alb_listener_arn != null ? 1 : 0

  name                 = "alb-${var.environment}-${replace(var.service_name, "_", "")}"
  port                 = var.service_port
  protocol             = "HTTP"
  target_type          = "ip"
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
  # if create_envoy is false - create target group
  count = var.alb_listener_arn != null ? 1 : 0

  listener_arn = var.alb_listener_arn

  action {
    type = "forward"
    # if custom target group is not defined - route to service target group
    target_group_arn = var.target_group_arn != null ? var.target_group_arn : aws_lb_target_group.service[0].arn
  }

  condition {
    host_header {
      values = ["${var.service_domain}.${data.aws_route53_zone.this.name}"]
      #      values = [var.listener_host_header]
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

data "aws_alb" "this" {
  arn = var.alb_arn
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


module "records_alb" {
  source  = "registry.terraform.io/terraform-aws-modules/route53/aws//modules/records"
  version = "~> 2.3"

  count = var.alb_listener_arn != null ? 1 : 0

  zone_id = data.aws_route53_zone.this.id

  records = [
    {
      name = var.service_domain
      type = "A"
      alias = {
        name    = data.aws_alb.this.dns_name
        zone_id = data.aws_alb.this.zone_id
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
      from_port   = var.service_port
      to_port     = var.service_port
      protocol    = "tcp"
      description = "${var.service_name} service port"
      cidr_blocks = data.aws_vpc.this.cidr_block
  }]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]


}



