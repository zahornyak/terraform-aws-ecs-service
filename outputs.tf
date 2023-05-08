output "ecs_service_arn" {
  value       = try(aws_ecs_service.service.id, null)
  description = "ecs_service_arn"
}

output "ecs_service_security_group_ids" {
  value       = try(values(module.service_container_sg)[*].security_group_id, null)
  description = "ecs service security group ids"
}

output "container_definitions" {
  value       = try(jsonencode(values(module.service_container_definition)[*].json_map_object), null)
  description = "container definitions of your task definition"
}

output "ecs_task_definition_arn" {
  value       = try(aws_ecs_task_definition.service.arn, null)
  description = "task definition arn"
}

output "ecs_service_name" {
  value       = try(aws_ecs_service.service.name, null)
  description = "ecs service name"
}

output "cloudwatch_log_group_arns" {
  value       = try(aws_cloudwatch_log_group.service_logs[*].arn, null)
  description = "aws cloudwatch log group arns"
}

output "lb_listener_certificate" {
  value       = try(aws_lb_listener_certificate.this[*].listener_arn, null)
  description = "lb listener certificate"
}

output "acm_arn" {
  value       = try(module.acm.acm_certificate_arn, null)
  description = "acm arn"
}

output "target_group_arns" {
  value       = try(aws_lb_target_group.service[*].arn, null)
  description = "target group arns"
}

output "lb_listener_rule_arns" {
  value       = try(aws_lb_listener_rule.service[*].arn, null)
  description = "load balancer listener rules arns"
}

output "ecs_task_execution_role_arn" {
  value       = module.ecs_task_execution_role.iam_role_arn
  description = "ecs task execution role arn"
}

output "ecs_task_policy_arn" {
  value       = module.ecs_task_policy.arn
  description = "ecs task policy arn"
}

output "ecs_task_role_arn" {
  value       = module.ecs_task_role.iam_role_arn
  description = "ecs task role arn"
}

output "records_lb_names" {
  value       = try(module.records_lb.route53_record_name, null)
  description = "load balancers records names"
}

output "service_container_sg_ids" {
  value       = try(module.service_container_sg[*].security_group_id, null)
  description = "service container sg ids"
}

output "aws_ecs_capacity_provider" {
  value       = try(aws_ecs_capacity_provider.main_ec2_autoscaling[0].name, null)
  description = "you should add this capacity provider to your cluster"
}

