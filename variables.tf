variable "service_name" {
  description = "Name of the service."
  type        = string
}

variable "service_cpu" {
  description = "CPU amount for the service."
  type        = number
}

variable "service_memory" {
  description = "Memory amount for the service."
  type        = number
}

variable "container_definitions" {
  type        = any
  default     = {}
  description = "Custom container definitions."
}

variable "requires_compatibilities" {
  type        = list(string)
  default     = ["FARGATE"]
  description = "Compatibilities for ECS task. Available: 'FARGATE', 'FARGATE_SPOT', 'EC2' etc."
}

variable "network_mode" {
  description = "Network mode for task. For example 'awsvpc' or 'bridge' etc."
  default     = "awsvpc"
  type        = string
}

variable "environment" {
  description = "Environment name. For example 'production'"
  type        = string
}

variable "desired_count" {
  description = "Desired count for service."
  type        = number
  default     = null
}

variable "cluster_name" {
  description = "Name of the ECS Cluster."
  type        = string
}

variable "launch_type" {
  description = "Launch type for service: 'FARGATE', 'EC2' etc."
  type        = string
  default     = "FARGATE"
}

variable "service_subnets" {
  description = "Subnets for service"
  type        = list(string)
}

variable "lb_listener_arn" {
  description = "Listener arn for load balancer connection"
  type        = string
  default     = null
}

variable "deployment_maximum_percent" {
  description = "deployment_maximum_percent. For example 200 will create twice more container and if everything is ok, deployment is succesfull."
  default     = 200
  type        = number
}

variable "deployment_minimum_healthy_percent" {
  description = "deployment_minimum_healthy_percent."
  default     = 100
  type        = number
}

variable "health_check_grace_period_seconds" {
  description = "health_check_grace_period_seconds"
  type        = number
  default     = null
}

variable "health_check" {
  description = "Custom healthcheck for target group."
  type        = any
  default     = null
}

variable "vpc_id" {
  description = "VPC id."
  type        = string
}

variable "deregistration_delay" {
  default     = 5
  type        = number
  description = "Deregistration delay for target group."
}

#variable "target_group_arn" {
#  default     = null
#  description = "Custom target group arn."
#  type        = string
#}

variable "route_53_zone_id" {
  description = "Route 53 zone id."
  type        = string
  default     = null
}

variable "task_role_policy_arns" {
  description = "Policies to attach to task role of ECS container."
  type        = list(string)
  default     = []
}

variable "lb_arn" {
  description = "Load balancer arn."
  type        = string
  default     = null
}

variable "assign_public_ip" {
  default     = false
  type        = bool
  description = "Assign_public_ip set true if you are using public subnets."
}

variable "security_groups" {
  description = "additional security_groups for service"
  type        = list(string)
  default     = []
}

variable "retention_in_days" {
  description = "retention_in_days"
  type        = number
  default     = 60
}

variable "tg_target_type" {
  description = "target group target type(ip or instance etc)"
  default     = "ip"
  type        = string
}

variable "tg_protocol" {
  description = "target group protocol(for example 'HTTP' or 'TCP')"
  default     = "HTTP"
  type        = string
}

variable "create_ssl" {
  type        = bool
  default     = true
  description = "defines if create ssl for services domains"
}

variable "vpc_cidr_block" {
  type        = string
  default     = null
  description = "cidr block for vpc. Use that variable when you dont have previously created VPC"
}

variable "route_53_zone_name" {
  type        = string
  default     = null
  description = "route 53 zone name. Use only when you dont have previously created Route53 zone"
}

variable "lb_dns_name" {
  type        = string
  default     = null
  description = "Load balancer dns name. Use only if you dont have previously created Load Balancer"
}

# scaling

variable "min_service_tasks" {
  description = "Minimum service tasks."
  type        = number
  default     = null
}

variable "max_service_tasks" {
  description = "Maximum service tasks."
  type        = number
  default     = null
}

variable "cpu_scaling_target_value" {
  description = "cpu_scaling target_value"
  type        = number
  default     = 30
}

variable "cpu_scale_in_cooldown" {
  description = "cpu scale_in_cooldown"
  type        = number
  default     = 300
}

variable "cpu_scale_out_cooldown" {
  description = "cpu scale_out_cooldown"
  type        = number
  default     = 120
}

variable "memory_scaling_target_value" {
  description = "memory scaling_target_value"
  type        = number
  default     = 60
}

variable "memory_scale_in_cooldown" {
  description = "memory scale_in_cooldown"
  type        = number
  default     = 300
}

variable "memory_scale_out_cooldown" {
  description = "memory scale_out_cooldown"
  type        = number
  default     = 120
}

variable "memory_scaling" {
  description = "if true - creates memory scaling"
  type        = bool
  default     = true
}

variable "cpu_scaling" {
  description = "if true - creates cpu scaling"
  type        = bool
  default     = true
}

variable "capacity_provider_strategy" {
  description = "capacity_provider_strategy"
  type        = any
  default     = {}
}

variable "ordered_placement_strategy" {
  description = "ordered_placement_strategy"
  type        = any
  default     = {}
}

variable "placement_constraints" {
  description = "placement_constraints"
  type        = any
  default     = {}
}




