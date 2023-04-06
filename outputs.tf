output "ecs_service_arn" {
  value       = aws_ecs_service.service.id
  description = "ecs_service_arn"
}

