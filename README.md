# Terraform AWS ECS service stack creation
This module is for whole ECS service stack creation: service, task definition, container definition, alb listener rule, target group, route53 record, security group etc.


## Example

```hcl
module "ecs_service" {
  source  = "zahornyak/ecs-service/aws"
  version = "0.0.1"

  region           = "eu-central-1"
  environment      = "production"
  vpc_id           = "vpc-080fd3cfeOa077792"
  service_subnets  = ["subnet-0c264c0a8557154cb","subnet-09e07c7e06d8b22e2","subnet-005217194adee6cdf"]
  cluster_name     = "production"
  route_53_zone_id = "Z0100384224HFJCZFL7A2"
  alb_arn          = "arn:aws:elasticloadbalancing:eu-central-1:01234567890:loadbalancer/app/production-alb/46633856495fd4b2"
  alb_listener_arn = "arn:aws:elasticloadbalancing:eu-central-1:01234567890:listener/app/production-alb/46633856495fd4b2/83d8743f8c9f02db"

  service_domain    = "api"
  service_name      = "backend"
  min_service_tasks = 1

  service_image_tag = "nginx:latest"

  service_memory = 256
  service_cpu    = 256
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
| <a name="module_ecs_task_execution_role"></a> [ecs\_task\_execution\_role](#module\_ecs\_task\_execution\_role) | terraform-aws-modules/iam/aws//modules/iam-assumable-role | ~> 4.4 |
| <a name="module_ecs_task_policy"></a> [ecs\_task\_policy](#module\_ecs\_task\_policy) | terraform-aws-modules/iam/aws//modules/iam-policy | ~> 4.4 |
| <a name="module_ecs_task_role"></a> [ecs\_task\_role](#module\_ecs\_task\_role) | terraform-aws-modules/iam/aws//modules/iam-assumable-role | ~> 4.4 |
| <a name="module_records_alb"></a> [records\_alb](#module\_records\_alb) | registry.terraform.io/terraform-aws-modules/route53/aws//modules/records | ~> 2.3 |
| <a name="module_service_container_definition"></a> [service\_container\_definition](#module\_service\_container\_definition) | registry.terraform.io/cloudposse/ecs-container-definition/aws | ~> 0.58 |
| <a name="module_service_container_sg"></a> [service\_container\_sg](#module\_service\_container\_sg) | registry.terraform.io/terraform-aws-modules/security-group/aws | ~> 4.3 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.service_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_service.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_lb_listener_rule.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_alb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/alb) | data source |
| [aws_iam_policy_document.ecs_task_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb_arn"></a> [alb\_arn](#input\_alb\_arn) | load balancer arn | `string` | n/a | yes |
| <a name="input_alb_listener_arn"></a> [alb\_listener\_arn](#input\_alb\_listener\_arn) | Listener arn for load balancer connection | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the ECS Cluster. | `string` | n/a | yes |
| <a name="input_container_definition"></a> [container\_definition](#input\_container\_definition) | your custom container definition | `map(any)` | `{}` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | deployment\_maximum\_percent. For example 200 will create twice more container and if everything is ok, deployment is succesfull. | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | deployment\_minimum\_healthy\_percent. | `number` | `100` | no |
| <a name="input_deregistration_delay"></a> [deregistration\_delay](#input\_deregistration\_delay) | deregistration\_delay for target group | `number` | `5` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Desired count for service. | `number` | `null` | no |
| <a name="input_docker_healthcheck"></a> [docker\_healthcheck](#input\_docker\_healthcheck) | Docker\_healthcheck for container. | <pre>object({<br>    command     = list(string)<br>    retries     = number<br>    timeout     = number<br>    interval    = number<br>    startPeriod = number<br>  })</pre> | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name. For example 'production' | `string` | n/a | yes |
| <a name="input_environment_files"></a> [environment\_files](#input\_environment\_files) | One or more files containing the environment variables to pass to the container. This maps to the --env-file option to docker run. The file must be hosted in Amazon S3. This option is only available to tasks using the EC2 launch type. This is a list of maps | <pre>list(object({<br>    value = string<br>    type  = string<br>  }))</pre> | `[]` | no |
| <a name="input_environment_vars"></a> [environment\_vars](#input\_environment\_vars) | Environment variables for container | <pre>list(object({<br>    name  = string<br>    value = string<br>  }))</pre> | `[]` | no |
| <a name="input_health_check"></a> [health\_check](#input\_health\_check) | health\_check | `any` | `null` | no |
| <a name="input_health_check_grace_period_seconds"></a> [health\_check\_grace\_period\_seconds](#input\_health\_check\_grace\_period\_seconds) | health\_check\_grace\_period\_seconds | `number` | `30` | no |
| <a name="input_launch_type"></a> [launch\_type](#input\_launch\_type) | launch\_type for service | `string` | `"FARGATE"` | no |
| <a name="input_log_configuration"></a> [log\_configuration](#input\_log\_configuration) | Log configuration | `map(any)` | `null` | no |
| <a name="input_min_service_tasks"></a> [min\_service\_tasks](#input\_min\_service\_tasks) | min\_service\_tasks | `number` | n/a | yes |
| <a name="input_network_mode"></a> [network\_mode](#input\_network\_mode) | Network\_mode for task. | `string` | `"awsvpc"` | no |
| <a name="input_port_mapping"></a> [port\_mapping](#input\_port\_mapping) | Custom port mapping for service. | <pre>list(object({<br>    containerPort = number<br>    hostPort      = number<br>    protocol      = string<br>  }))</pre> | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | Your region. | `string` | n/a | yes |
| <a name="input_requires_compatibilities"></a> [requires\_compatibilities](#input\_requires\_compatibilities) | Compatibilities for ECS task. Available: 'FARGATE', 'FARGATE\_SPOT', 'EC2' etc. | `list(string)` | <pre>[<br>  "FARGATE"<br>]</pre> | no |
| <a name="input_route_53_zone_id"></a> [route\_53\_zone\_id](#input\_route\_53\_zone\_id) | route 53 zone id | `string` | n/a | yes |
| <a name="input_secrets"></a> [secrets](#input\_secrets) | Secrets for container | <pre>list(object({<br>    name      = string<br>    valueFrom = string<br>  }))</pre> | `[]` | no |
| <a name="input_service_cpu"></a> [service\_cpu](#input\_service\_cpu) | CPU amount for the service. | `number` | n/a | yes |
| <a name="input_service_domain"></a> [service\_domain](#input\_service\_domain) | domain of your service. For example in help.google.com your service domain is 'help' | `string` | n/a | yes |
| <a name="input_service_image_tag"></a> [service\_image\_tag](#input\_service\_image\_tag) | Docker image for service. | `string` | n/a | yes |
| <a name="input_service_memory"></a> [service\_memory](#input\_service\_memory) | Memory amount for the service. | `number` | n/a | yes |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | Name of the service. | `string` | n/a | yes |
| <a name="input_service_port"></a> [service\_port](#input\_service\_port) | Port for your service. | `number` | `null` | no |
| <a name="input_service_subnets"></a> [service\_subnets](#input\_service\_subnets) | subnets for service | `list(string)` | n/a | yes |
| <a name="input_target_group_arn"></a> [target\_group\_arn](#input\_target\_group\_arn) | custom target group arn | `string` | `null` | no |
| <a name="input_task_role_policy_arns"></a> [task\_role\_policy\_arns](#input\_task\_role\_policy\_arns) | Policies to attach to task role of ECS container | `list(string)` | `[]` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | vpc\_id | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->