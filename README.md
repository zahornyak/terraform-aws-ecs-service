# Terraform AWS ECS service stack creation
![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/zahornyak/terraform-aws-ecs-service)

This module is for whole ECS service stack creation: service, task definition, container definition, alb listener rule, target group, route53 record, security group etc.

### Important note:
- *Load balancer and listener should be created before.*
- *Use `connect_to_lb` and `service_domain` to connect service container to load balancer and create route53 A record*
- 
## Example

### Single container
```hcl
module "ecs_service" {
  source  = "zahornyak/ecs-service/aws"

  region          = "eu-central-1"
  environment     = "production"
  vpc_id          = "vpc-080fd3099892"
  service_subnets = ["subnet-0c264c7154cb", "subnet-09e0d8b22e2"]
  # assign_public_ip = true # if you are using public subnets
  cluster_name     = "production-cluster"
  route_53_zone_id = "Z01006347593463S0ZFL7A2"
  lb_arn           = "arn:aws:elasticloadbalancing:eu-central-1:1234567890:loadbalancer/app/plugin-development-alb/46555556595fd4b2"
  lb_listener_arn  = "arn:aws:elasticloadbalancing:eu-central-1:1234567890:listener/app/plugin-development-alb/46555556595fd4b2/83d6940f8c9f02db"
  create_ssl       = true # requests ssl for service and attach it to listener rule

  service_name  = "backend"
  desired_count = 1

  container_definitions = {
    proxy = {
      service_domain   = "api-test"
      connect_to_lb    = true
      container_image  = "nginx:latest"
      container_name   = "proxy"
      container_cpu    = 256
      container_memory = 256
      containerPort    = 80
      environment = [
        {
          "name"  = "foo"
          "value" = "bar"
        }
      ]
    }
  }

  service_memory  = 1024
  service_cpu     = 512
}
```

### Multiple containers
```hcl
module "ecs_service" {
  source  = "zahornyak/ecs-service/aws"

  region          = "eu-central-1"
  environment     = "production"
  vpc_id          = "vpc-080fd3099892"
  service_subnets = ["subnet-0c264c7154cb", "subnet-09e0d8b22e2"]
  # assign_public_ip = true # if you are using public subnets
  cluster_name     = "production-cluster"
  route_53_zone_id = "Z01006347593463S0ZFL7A2"
  lb_arn           = "arn:aws:elasticloadbalancing:eu-central-1:1234567890:loadbalancer/app/plugin-development-alb/46555556595fd4b2"
  lb_listener_arn  = "arn:aws:elasticloadbalancing:eu-central-1:1234567890:listener/app/plugin-development-alb/46555556595fd4b2/83d6940f8c9f02db"
  create_ssl       = true # requests ssl for service and attach it to listener rule

  service_name  = "backend"
  desired_count = 1

  container_definitions = {
    proxy = {
      service_domain   = "api-test"
      connect_to_lb    = true
      container_image  = "nginx:latest"
      container_name   = "proxy"
      container_cpu    = 256
      container_memory = 256
      containerPort    = 80
      environment = [
        {
          "name"  = "foo"
          "value" = "bar"
        }
      ]
    }
    backend = {
      container_image  = "nginx:latest"
      container_name   = "backend"
      container_cpu    = 256
      container_memory = 256
      container_depends_on = [
        {
          containerName = "proxy"
          condition     = "START"
        }
      ]
      containerPort = 3000
      healthcheck = {
        retries     = 5
        command     = ["CMD-SHELL", "curl -f http://localhost:3000"]
        timeout     = 15
        interval    = 30
        startPeriod = 10
      }
      environment = [
        {
          "name"  = "foo"
          "value" = "bar"
        }
      ]
    }
    admin = {
      service_domain   = "api-worker"
      connect_to_lb    = true
      container_image  = "nginx:latest"
      container_name   = "worker"
      container_cpu    = 256
      container_memory = 256
      container_depends_on = [
        {
          containerName = "backend"
          condition     = "START"
        }
      ]
      containerPort = 3050
      healthcheck = {
        retries     = 5
        command     = ["CMD-SHELL", "curl -f http://localhost:3050"]
        timeout     = 15
        interval    = 30
        startPeriod = 10
      }
      environment = [
        {
          "name"  = "foo"
          "value" = "bar"
        }
      ]
    }
    }
  }

  service_memory  = 1024
  service_cpu     = 512
}
```


<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 4.37 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 4.37 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_acm"></a> [acm](#module\_acm) | terraform-aws-modules/acm/aws | ~> 3.3.0 |
| <a name="module_ecs_task_execution_role"></a> [ecs\_task\_execution\_role](#module\_ecs\_task\_execution\_role) | terraform-aws-modules/iam/aws//modules/iam-assumable-role | ~> 4.4 |
| <a name="module_ecs_task_policy"></a> [ecs\_task\_policy](#module\_ecs\_task\_policy) | terraform-aws-modules/iam/aws//modules/iam-policy | ~> 4.4 |
| <a name="module_ecs_task_role"></a> [ecs\_task\_role](#module\_ecs\_task\_role) | terraform-aws-modules/iam/aws//modules/iam-assumable-role | ~> 4.4 |
| <a name="module_records_lb"></a> [records\_lb](#module\_records\_lb) | registry.terraform.io/terraform-aws-modules/route53/aws//modules/records | ~> 2.3 |
| <a name="module_service_container_definition"></a> [service\_container\_definition](#module\_service\_container\_definition) | registry.terraform.io/cloudposse/ecs-container-definition/aws | ~> 0.58 |
| <a name="module_service_container_sg"></a> [service\_container\_sg](#module\_service\_container\_sg) | registry.terraform.io/terraform-aws-modules/security-group/aws | ~> 4.3 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.service_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_service.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_lb_listener_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_certificate) | resource |
| [aws_lb_listener_rule.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_iam_policy_document.ecs_task_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Assign\_public\_ip set true if you are using public subnets. | `bool` | `false` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the ECS Cluster. | `string` | n/a | yes |
| <a name="input_container_definitions"></a> [container\_definitions](#input\_container\_definitions) | Custom container definitions. | `any` | `{}` | no |
| <a name="input_create_ssl"></a> [create\_ssl](#input\_create\_ssl) | defines if create ssl for services domains | `bool` | `true` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | deployment\_maximum\_percent. For example 200 will create twice more container and if everything is ok, deployment is succesfull. | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | deployment\_minimum\_healthy\_percent. | `number` | `100` | no |
| <a name="input_deregistration_delay"></a> [deregistration\_delay](#input\_deregistration\_delay) | Deregistration delay for target group. | `number` | `5` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Desired count for service. | `number` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name. For example 'production' | `string` | n/a | yes |
| <a name="input_health_check"></a> [health\_check](#input\_health\_check) | Custom healthcheck for target group. | `any` | `null` | no |
| <a name="input_health_check_grace_period_seconds"></a> [health\_check\_grace\_period\_seconds](#input\_health\_check\_grace\_period\_seconds) | health\_check\_grace\_period\_seconds | `number` | `30` | no |
| <a name="input_launch_type"></a> [launch\_type](#input\_launch\_type) | Launch type for service: 'FARGATE', 'EC2' etc. | `string` | `"FARGATE"` | no |
| <a name="input_lb_arn"></a> [lb\_arn](#input\_lb\_arn) | Load balancer arn. | `string` | `null` | no |
| <a name="input_lb_listener_arn"></a> [lb\_listener\_arn](#input\_lb\_listener\_arn) | Listener arn for load balancer connection | `string` | `null` | no |
| <a name="input_min_service_tasks"></a> [min\_service\_tasks](#input\_min\_service\_tasks) | Minimum service tasks. | `number` | `null` | no |
| <a name="input_network_mode"></a> [network\_mode](#input\_network\_mode) | Network mode for task. For example 'awsvpc' or 'bridge' etc. | `string` | `"awsvpc"` | no |
| <a name="input_region"></a> [region](#input\_region) | Your region. | `string` | n/a | yes |
| <a name="input_requires_compatibilities"></a> [requires\_compatibilities](#input\_requires\_compatibilities) | Compatibilities for ECS task. Available: 'FARGATE', 'FARGATE\_SPOT', 'EC2' etc. | `list(string)` | <pre>[<br>  "FARGATE"<br>]</pre> | no |
| <a name="input_retention_in_days"></a> [retention\_in\_days](#input\_retention\_in\_days) | retention\_in\_days | `number` | `60` | no |
| <a name="input_route_53_zone_id"></a> [route\_53\_zone\_id](#input\_route\_53\_zone\_id) | Route 53 zone id. | `string` | n/a | yes |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups) | additional security\_groups for service | `list(string)` | `[]` | no |
| <a name="input_service_cpu"></a> [service\_cpu](#input\_service\_cpu) | CPU amount for the service. | `number` | n/a | yes |
| <a name="input_service_memory"></a> [service\_memory](#input\_service\_memory) | Memory amount for the service. | `number` | n/a | yes |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | Name of the service. | `string` | n/a | yes |
| <a name="input_service_subnets"></a> [service\_subnets](#input\_service\_subnets) | Subnets for service | `list(string)` | n/a | yes |
| <a name="input_task_role_policy_arns"></a> [task\_role\_policy\_arns](#input\_task\_role\_policy\_arns) | Policies to attach to task role of ECS container. | `list(string)` | `[]` | no |
| <a name="input_tg_protocol"></a> [tg\_protocol](#input\_tg\_protocol) | target group protocol(for example 'HTTP' or 'TCP') | `string` | `"HTTP"` | no |
| <a name="input_tg_target_type"></a> [tg\_target\_type](#input\_tg\_target\_type) | target group target type(ip or instance etc) | `string` | `"ip"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC id. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ecs_service_arn"></a> [ecs\_service\_arn](#output\_ecs\_service\_arn) | ecs\_service\_arn |
| <a name="output_ecs_service_security_group_ids"></a> [ecs\_service\_security\_group\_ids](#output\_ecs\_service\_security\_group\_ids) | ecs service security group ids |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->