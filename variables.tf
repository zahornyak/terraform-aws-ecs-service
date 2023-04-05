variable "service_image_tag" {
  description = "Docker image for service."
  type        = string
}

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

variable "region" {
  description = "Your region."
  type        = string
}

variable "docker_healthcheck" {
  description = "Docker_healthcheck for container."
  type = object({
    command     = list(string)
    retries     = number
    timeout     = number
    interval    = number
    startPeriod = number
  })
  default = null
}

variable "service_port" {
  description = "Port for your service."
  type        = number
  default     = null
}

variable "port_mapping" {
  description = "Custom port mapping for service."
  type = list(object({
    containerPort = number
    hostPort      = number
    protocol      = string
  }))
  default = null
}

variable "environment_vars" {
  description = "Environment variables for container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "secrets" {
  description = "Secrets for container"
  type = list(object({
    name      = string
    valueFrom = string
  }))
  default = []
}

variable "log_configuration" {
  description = "Log configuration"
  type        = map(any)
  default     = null
}

variable "environment_files" {
  description = "One or more files containing the environment variables to pass to the container. This maps to the --env-file option to docker run. The file must be hosted in Amazon S3. This option is only available to tasks using the EC2 launch type. This is a list of maps"
  type = list(object({
    value = string
    type  = string
  }))
  default = []
}

variable "container_definition" {
  type        = map(any)
  default     = {}
  description = "your custom container definition"
}

variable "requires_compatibilities" {
  type        = list(string)
  default     = ["FARGATE"]
  description = "Compatibilities for ECS task. Available: 'FARGATE', 'FARGATE_SPOT', 'EC2' etc."
}

variable "network_mode" {
  description = "Network_mode for task."
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

variable "min_service_tasks" {
  description = "min_service_tasks"
  type        = number
}

variable "cluster_name" {
  description = "Name of the ECS Cluster."
  type        = string
}

variable "launch_type" {
  description = "launch_type for service"
  type        = string
  default     = "FARGATE"
}

variable "service_subnets" {
  description = "subnets for service"
  type        = list(string)
}

variable "alb_listener_arn" {
  description = "Listener arn for load balancer connection"
  type        = string
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
  default     = 30
}

variable "health_check" {
  description = "health_check"
  type        = any
  default     = null
}

variable "vpc_id" {
  description = "vpc_id"
  type        = string
}

variable "deregistration_delay" {
  default     = 5
  type        = number
  description = "deregistration_delay for target group"
}

variable "target_group_arn" {
  default     = null
  description = "custom target group arn"
  type        = string
}

variable "service_domain" {
  description = "domain of your service. For example in help.google.com your service domain is 'help'"
  type        = string
}

variable "route_53_zone_id" {
  description = "route 53 zone id"
  type        = string
}

variable "task_role_policy_arns" {
  description = "Policies to attach to task role of ECS container"
  type        = list(string)
  default     = []
}

variable "alb_arn" {
  description = "load balancer arn"
  type        = string
}

variable "assign_public_ip" {
  default     = false
  type        = bool
  description = "assign_public_ip set true if you are using public ips"
}

variable "create_ssl" {
  default     = true
  type        = bool
  description = "creates ssl certificate for your service and attach it to alb listener"
}