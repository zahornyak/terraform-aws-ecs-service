output "ecs_service_arn" {
  value       = aws_ecs_service.service.id
  description = "ecs_service_arn"
}

output "ecs_service_security_group_id" {
  value       = module.service_container_sg.security_group_id
  description = "ecs_service_security_group_id"
}