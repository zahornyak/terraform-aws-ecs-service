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
  desired_count          = var.desired_count ? var.desired_count : var.min_service_tasks
  cluster                = var.cluster_name
  enable_execute_command = true
  launch_type            = var.launch_type

  network_configuration {
    subnets         = var.service_subnets
    security_groups = [module.service_container_sg.security_group_id]
  }

  dynamic "load_balancer" {
    # if listener_arn is defined - :create load balancer association block
    for_each = var.alb_listener_arn != null ? [] : [1]
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
  health_check_grace_period_seconds = var.alb_listener_arn ? var.health_check_grace_period_seconds : null

}

resource "aws_cloudwatch_log_group" "service_logs" {
  name              = "${var.environment}-${var.service_name}-logs"
  retention_in_days = 60
}


