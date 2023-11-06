# Terraform AWS ECS service stack creation
![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/zahornyak/terraform-aws-ecs-service)

This module is for whole ECS service stack creation: service, task definition, container definition, alb listener rule, target group, route53 record, security group etc.

### Important note:
- *Use `connect_to_lb` and `service_domain` to connect service container to load balancer and create route53 A record*
- *Use `vpc_cidr_block`, `route_53_zone_name`, `lb_dns_name` only when you dont have previously created resources*


## Example

### Single container
```hcl
module "ecs_service" {
  source = "zahornyak/ecs-service/aws"

  environment        = "production"
  vpc_id             = "vpc-080fd3099892"
  vpc_cidr_block     = "10.0.0.0/16" # use when you dont have previously created vpc
  service_subnets    = ["subnet-0c264c7154cb", "subnet-09e0d8b22e2"]
  # assign_public_ip = true # if you are using public subnets
  cluster_name       = "production-cluster"
  route_53_zone_id   = "Z01006347593463S0ZFL7A2" # use when you dont have previously created Route53 zone
  route_53_zone_name = "example.com" 
  lb_arn             = "arn:aws:elasticloadbalancing:eu-central-1:1234567890:loadbalancer/app/plugin-development-alb/46555556595fd4b2"
  lb_listener_arn    = "arn:aws:elasticloadbalancing:eu-central-1:1234567890:listener/app/plugin-development-alb/46555556595fd4b2/83d6940f8c9f02db"
  lb_dns_name        = "my-loadbalancer-1234567890.us-west-2.elb.amazonaws.com" # use when you dont have previously created load balancer
  create_ssl         = true # requests ssl for service and attach it to listener rule

  service_name  = "backend"
  desired_count = 1

  container_definitions = {
    proxy = {
      service_domain   = "api-test"
      connect_to_lb    = true
      container_image  = "nginx:latest"
      container_name   = "backend"
      container_cpu    = 256
      container_memory = 256
      containerPort    = 80
      environment      = [
        {
          "name"  = "foo"
          "value" = "bar"
        }
      ]
    }
  }

  service_memory = 1024
  service_cpu    = 512
}
```

### Multiple containers
```hcl
module "ecs_service" {
  source  = "zahornyak/ecs-service/aws"

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
  service_memory  = 1024
  service_cpu     = 512
}
```

### No load balancer
```hcl
module "ecs_service" {
  source = "zahornyak/ecs-service/aws"

  environment     = var.environment
  vpc_id          = var.vpc_id
  service_subnets = var.subnets
  vpc_cidr_block  = var.vpc_cidr_block

  # assign_public_ip = true # if you are using public subnets
  cluster_name = aws_ecs_cluster.ecs_cluster.name

  service_name  = "backend"
  desired_count = 1

  container_definitions = {
    proxy = {
      container_image  = "nginx:latest"
      container_name   = "proxy"
      container_cpu    = 256
      container_memory = 256
      containerPort    = 80
      environment      = [
        {
          "name"  = "foo"
          "value" = "bar"
        }
      ]
    }
    
    backend = {
      container_image      = "nginx:latest"
      container_name       = "backend"
      container_cpu        = 256
      container_memory     = 256
      container_depends_on = [
        {
          containerName = "proxy"
          condition     = "START"
        }
      ]
      containerPort = 3000
      healthcheck   = {
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
  }

  service_memory = 1024
  service_cpu    = 512
}
```


### Example of using environment valiables for containers(using ssm_secrets which creates ssm parameters and puts them into container definition)
```hcl
module "ecs-service" {
  source  = "zahornyak/ecs-service/aws"
  # insert the 7 required variables here
  container_definitions = {
    proxy = {
      container_image  = "nginx:latest"
      container_name   = "proxy"
      container_cpu    = 256
      container_memory = 256
      containerPort    = 80
      environment      = [
        {
          "name"  = "foo"
          "value" = "bar"
        }
      ]
      ssm_secrets = {
        DEBUG = {
          value = "true"
        }
      }
    }
  }
}
```

### Example of using environment valiables for containers(using ssm_env_file which parses and creates ssm parameters and puts them into container definition)
```hcl
module "ecs-service" {
  source  = "zahornyak/ecs-service/aws"
  # insert the 7 required variables here
  container_definitions = {
    proxy = {
      container_image  = "nginx:latest"
      container_name   = "proxy"
      container_cpu    = 256
      container_memory = 256
      containerPort    = 80
      environment      = [
        {
          "name"  = "foo"
          "value" = "bar"
        }
      ]
      ssm_env_file = "./env"
    }
  }
}
```
\
.env example
```commandline
LOG_LEVEL=verbose
LOG_TARGET=console
LOG_FORMAT=json

CRONJOB_ENABLED=true
DEPLOYMENT=develop
```

### Autoscaling with scaling values
```hcl
module "ecs-service" {
  source = "zahornyak/ecs-service/aws"
  # insert the 7 required variables here

  min_service_tasks = 1
  max_service_tasks = 6

  cpu_scaling_target_value = 40
  cpu_scale_in_cooldown    = 350
  cpu_scale_out_cooldown   = 200

  memory_scaling_target_value = 90
  memory_scale_in_cooldown    = 350
  memory_scale_out_cooldown   = 300
}
```
### Autoscaling with scaling values (no memory or cpu scaling)
```hcl
module "ecs-service" {
  source = "zahornyak/ecs-service/aws"
  # insert the 7 required variables here

  min_service_tasks = 1
  max_service_tasks = 6

  cpu_scaling_target_value = 40
  cpu_scale_in_cooldown    = 350
  cpu_scale_out_cooldown   = 200
  
}
```

### Capacity provider strategy, ordered placement, placement_constraints strategy example configuration
```hcl
module "ecs-service" {
  source = "zahornyak/ecs-service/aws"
  # insert the 7 required variables here

  capacity_provider_strategy = {
    main = {
      capacity_provider = "FARGATE_SPOT"
      base              = 1
      weight            = 1
    }
  }


  ordered_placement_strategy = {
    test = {
      type  = "binpack"
      field = "cpu"
    }
  }


  placement_constraints = {
    example = {
      type       = "memberOf"
      expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
    }
  }
}
```

### Service discovery example
```hcl
module "ecs-service" {
  source = "zahornyak/ecs-service/aws"
  # insert the 7 required variables here

  create_service_discovery = true
  discovery_registry_id    = "service_discovery_registry_id"
  
}
```


<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 4.37 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 4.37 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_acm"></a> [acm](#module\_acm) | terraform-aws-modules/acm/aws | ~> 3.3 |
| <a name="module_ecs_task_exec_policy"></a> [ecs\_task\_exec\_policy](#module\_ecs\_task\_exec\_policy) | terraform-aws-modules/iam/aws//modules/iam-policy | ~> 4.4 |
| <a name="module_ecs_task_execution_role"></a> [ecs\_task\_execution\_role](#module\_ecs\_task\_execution\_role) | terraform-aws-modules/iam/aws//modules/iam-assumable-role | ~> 4.4 |
| <a name="module_ecs_task_policy"></a> [ecs\_task\_policy](#module\_ecs\_task\_policy) | terraform-aws-modules/iam/aws//modules/iam-policy | ~> 4.4 |
| <a name="module_ecs_task_role"></a> [ecs\_task\_role](#module\_ecs\_task\_role) | terraform-aws-modules/iam/aws//modules/iam-assumable-role | ~> 4.4 |
| <a name="module_env_variables"></a> [env\_variables](#module\_env\_variables) | zahornyak/multiple-ssm-parameters/aws | 0.0.11 |
| <a name="module_service_container_definition"></a> [service\_container\_definition](#module\_service\_container\_definition) | registry.terraform.io/cloudposse/ecs-container-definition/aws | ~> 0.58 |
| <a name="module_service_container_sg"></a> [service\_container\_sg](#module\_service\_container\_sg) | registry.terraform.io/terraform-aws-modules/security-group/aws | ~> 4.3 |

## Resources

| Name | Type |
|------|------|
| [aws_appautoscaling_policy.target_tracking_scaling_cpu_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.target_tracking_scaling_memory_service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_target.service_scaling](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_cloudwatch_log_group.service_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_service.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_lb_listener_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_certificate) | resource |
| [aws_lb_listener_rule.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_rule) | resource |
| [aws_lb_target_group.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_route53_record.lb_records](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_service_discovery_service.service](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.ecs_task_exec_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ecs_task_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/lb) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route53_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_assign_public_ip"></a> [assign\_public\_ip](#input\_assign\_public\_ip) | Assign\_public\_ip set true if you are using public subnets. | `bool` | `false` | no |
| <a name="input_capacity_provider_strategy"></a> [capacity\_provider\_strategy](#input\_capacity\_provider\_strategy) | capacity\_provider\_strategy | `any` | `{}` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the ECS Cluster. | `string` | n/a | yes |
| <a name="input_container_definitions"></a> [container\_definitions](#input\_container\_definitions) | Custom container definitions. | `any` | `{}` | no |
| <a name="input_cpu_scale_in_cooldown"></a> [cpu\_scale\_in\_cooldown](#input\_cpu\_scale\_in\_cooldown) | cpu scale\_in\_cooldown | `number` | `null` | no |
| <a name="input_cpu_scale_out_cooldown"></a> [cpu\_scale\_out\_cooldown](#input\_cpu\_scale\_out\_cooldown) | cpu scale\_out\_cooldown | `number` | `null` | no |
| <a name="input_cpu_scaling_target_value"></a> [cpu\_scaling\_target\_value](#input\_cpu\_scaling\_target\_value) | cpu\_scaling target\_value | `number` | `null` | no |
| <a name="input_create_service_discovery"></a> [create\_service\_discovery](#input\_create\_service\_discovery) | creates service discovery service and connects in to ecs service | `bool` | `false` | no |
| <a name="input_create_ssl"></a> [create\_ssl](#input\_create\_ssl) | defines if create ssl for services domains | `bool` | `true` | no |
| <a name="input_deployment_circuit_breaker"></a> [deployment\_circuit\_breaker](#input\_deployment\_circuit\_breaker) | deployment\_circuit\_breaker configuration | `any` | `{}` | no |
| <a name="input_deployment_maximum_percent"></a> [deployment\_maximum\_percent](#input\_deployment\_maximum\_percent) | deployment\_maximum\_percent. For example 200 will create twice more container and if everything is ok, deployment is succesfull. | `number` | `200` | no |
| <a name="input_deployment_minimum_healthy_percent"></a> [deployment\_minimum\_healthy\_percent](#input\_deployment\_minimum\_healthy\_percent) | deployment\_minimum\_healthy\_percent. | `number` | `100` | no |
| <a name="input_deregistration_delay"></a> [deregistration\_delay](#input\_deregistration\_delay) | Deregistration delay for target group. | `number` | `5` | no |
| <a name="input_desired_count"></a> [desired\_count](#input\_desired\_count) | Desired count for service. | `number` | `null` | no |
| <a name="input_discovery_registry_id"></a> [discovery\_registry\_id](#input\_discovery\_registry\_id) | service discovery registry\_id | `string` | `null` | no |
| <a name="input_docker_volume"></a> [docker\_volume](#input\_docker\_volume) | docker volume | `any` | `null` | no |
| <a name="input_efs_volume"></a> [efs\_volume](#input\_efs\_volume) | efs volume | `any` | `null` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name. For example 'production' | `string` | n/a | yes |
| <a name="input_health_check"></a> [health\_check](#input\_health\_check) | Custom healthcheck for target group. | `any` | `null` | no |
| <a name="input_health_check_grace_period_seconds"></a> [health\_check\_grace\_period\_seconds](#input\_health\_check\_grace\_period\_seconds) | health\_check\_grace\_period\_seconds | `number` | `null` | no |
| <a name="input_launch_type"></a> [launch\_type](#input\_launch\_type) | Launch type for service: 'FARGATE', 'EC2' etc. | `string` | `"FARGATE"` | no |
| <a name="input_lb_arn"></a> [lb\_arn](#input\_lb\_arn) | Load balancer arn. | `string` | `null` | no |
| <a name="input_lb_dns_name"></a> [lb\_dns\_name](#input\_lb\_dns\_name) | Load balancer dns name. Use only if you dont have previously created Load Balancer | `string` | `null` | no |
| <a name="input_lb_listener_arn"></a> [lb\_listener\_arn](#input\_lb\_listener\_arn) | Listener arn for load balancer connection | `string` | `null` | no |
| <a name="input_lb_zone_id"></a> [lb\_zone\_id](#input\_lb\_zone\_id) | load balancer zone id | `string` | `null` | no |
| <a name="input_max_service_tasks"></a> [max\_service\_tasks](#input\_max\_service\_tasks) | Maximum service tasks. | `number` | `null` | no |
| <a name="input_memory_scale_in_cooldown"></a> [memory\_scale\_in\_cooldown](#input\_memory\_scale\_in\_cooldown) | memory scale\_in\_cooldown | `number` | `null` | no |
| <a name="input_memory_scale_out_cooldown"></a> [memory\_scale\_out\_cooldown](#input\_memory\_scale\_out\_cooldown) | memory scale\_out\_cooldown | `number` | `null` | no |
| <a name="input_memory_scaling_target_value"></a> [memory\_scaling\_target\_value](#input\_memory\_scaling\_target\_value) | memory scaling\_target\_value | `number` | `null` | no |
| <a name="input_min_service_tasks"></a> [min\_service\_tasks](#input\_min\_service\_tasks) | Minimum service tasks. | `number` | `null` | no |
| <a name="input_network_mode"></a> [network\_mode](#input\_network\_mode) | Network mode for task. For example 'awsvpc' or 'bridge' etc. | `string` | `"awsvpc"` | no |
| <a name="input_ordered_placement_strategy"></a> [ordered\_placement\_strategy](#input\_ordered\_placement\_strategy) | ordered\_placement\_strategy | `any` | `{}` | no |
| <a name="input_parameter_prefix"></a> [parameter\_prefix](#input\_parameter\_prefix) | prefix for parameter store parameter. For example '/develop/service/'. So parameter 'DEBUG' will have '/develop/service/DEBUG' name on the parameter store | `string` | `null` | no |
| <a name="input_placement_constraints"></a> [placement\_constraints](#input\_placement\_constraints) | placement\_constraints | `any` | `{}` | no |
| <a name="input_protocol_version"></a> [protocol\_version](#input\_protocol\_version) | target group protocol version | `string` | `null` | no |
| <a name="input_requires_compatibilities"></a> [requires\_compatibilities](#input\_requires\_compatibilities) | Compatibilities for ECS task. Available: 'FARGATE', 'FARGATE\_SPOT', 'EC2' etc. | `list(string)` | <pre>[<br>  "FARGATE"<br>]</pre> | no |
| <a name="input_retention_in_days"></a> [retention\_in\_days](#input\_retention\_in\_days) | retention\_in\_days | `number` | `60` | no |
| <a name="input_route_53_zone_id"></a> [route\_53\_zone\_id](#input\_route\_53\_zone\_id) | Route 53 zone id. | `string` | `null` | no |
| <a name="input_route_53_zone_name"></a> [route\_53\_zone\_name](#input\_route\_53\_zone\_name) | route 53 zone name. Use only when you dont have previously created Route53 zone | `string` | `null` | no |
| <a name="input_runtime_platform"></a> [runtime\_platform](#input\_runtime\_platform) | runtime platform | `any` | `null` | no |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups) | additional security\_groups for service | `list(string)` | `[]` | no |
| <a name="input_service_cpu"></a> [service\_cpu](#input\_service\_cpu) | CPU amount for the service. | `number` | n/a | yes |
| <a name="input_service_memory"></a> [service\_memory](#input\_service\_memory) | Memory amount for the service. | `number` | n/a | yes |
| <a name="input_service_name"></a> [service\_name](#input\_service\_name) | Name of the service. | `string` | n/a | yes |
| <a name="input_service_subnets"></a> [service\_subnets](#input\_service\_subnets) | Subnets for service | `list(string)` | n/a | yes |
| <a name="input_task_exec_role_policy_arns"></a> [task\_exec\_role\_policy\_arns](#input\_task\_exec\_role\_policy\_arns) | Additional policies to attach to task execution role of ECS container. | `list(string)` | `[]` | no |
| <a name="input_task_role_policy_arns"></a> [task\_role\_policy\_arns](#input\_task\_role\_policy\_arns) | Additional policies to attach to task role of ECS container. | `list(string)` | `[]` | no |
| <a name="input_tg_protocol"></a> [tg\_protocol](#input\_tg\_protocol) | target group protocol(for example 'HTTP' or 'TCP') | `string` | `"HTTP"` | no |
| <a name="input_tg_target_type"></a> [tg\_target\_type](#input\_tg\_target\_type) | target group target type(ip or instance etc) | `string` | `"ip"` | no |
| <a name="input_vpc_cidr_block"></a> [vpc\_cidr\_block](#input\_vpc\_cidr\_block) | cidr block for vpc. Use that variable when you dont have previously created VPC | `string` | `null` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC id. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acm_arn"></a> [acm\_arn](#output\_acm\_arn) | acm arn |
| <a name="output_cloudwatch_log_group_arns"></a> [cloudwatch\_log\_group\_arns](#output\_cloudwatch\_log\_group\_arns) | aws cloudwatch log group arns |
| <a name="output_container_definitions"></a> [container\_definitions](#output\_container\_definitions) | container definitions of your task definition |
| <a name="output_ecs_service_arn"></a> [ecs\_service\_arn](#output\_ecs\_service\_arn) | ecs\_service\_arn |
| <a name="output_ecs_service_name"></a> [ecs\_service\_name](#output\_ecs\_service\_name) | ecs service name |
| <a name="output_ecs_service_security_group_ids"></a> [ecs\_service\_security\_group\_ids](#output\_ecs\_service\_security\_group\_ids) | ecs service security group ids |
| <a name="output_ecs_task_definition_arn"></a> [ecs\_task\_definition\_arn](#output\_ecs\_task\_definition\_arn) | task definition arn |
| <a name="output_ecs_task_execution_role_arn"></a> [ecs\_task\_execution\_role\_arn](#output\_ecs\_task\_execution\_role\_arn) | ecs task execution role arn |
| <a name="output_ecs_task_policy_arn"></a> [ecs\_task\_policy\_arn](#output\_ecs\_task\_policy\_arn) | ecs task policy arn |
| <a name="output_ecs_task_role_arn"></a> [ecs\_task\_role\_arn](#output\_ecs\_task\_role\_arn) | ecs task role arn |
| <a name="output_lb_listener_certificate"></a> [lb\_listener\_certificate](#output\_lb\_listener\_certificate) | lb listener certificate |
| <a name="output_lb_listener_rule_arns"></a> [lb\_listener\_rule\_arns](#output\_lb\_listener\_rule\_arns) | load balancer listener rules arns |
| <a name="output_records_lb_names"></a> [records\_lb\_names](#output\_records\_lb\_names) | load balancers records names |
| <a name="output_service_container_sg_ids"></a> [service\_container\_sg\_ids](#output\_service\_container\_sg\_ids) | service container sg ids |
| <a name="output_target_group_arns"></a> [target\_group\_arns](#output\_target\_group\_arns) | target group arns |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
