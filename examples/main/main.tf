module "ecs_service" {
  source = "zahornyak/ecs-service/aws"

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

  service_memory = 1024
  service_cpu    = 512

  # Optional: Add additional inline IAM policies to task role
  # Map format: policy names (keys) to policy JSON documents (values)
  # task_role_policy_json = {
  #   s3_access = data.aws_iam_policy_document.s3_access.json
  # }

  # Optional: Add additional inline IAM policies to task execution role
  # task_exec_role_policy_json = {
  #   cloudwatch_logs = data.aws_iam_policy_document.cloudwatch_logs.json
  # }
}
