module "ecs_service" {
  source  = "zahornyak/ecs-service/aws"
  version = "0.0.4"

  region          = "eu-central-1"
  environment     = "test"
  vpc_id          = "vpc-080fd3cfe0a555592"
  service_subnets = ["subnet-0c264c0a9997154cb", "subnet-09e07c7e0999b22e2"]
  # assign_public_ip = true # if you are using public subnets
  cluster_name     = "test-cluster"
  route_53_zone_id = "Z01006876543TS0ZFL7A2"
  alb_arn          = "arn:aws:elasticloadbalancing:eu-central-1:01234567890:loadbalancer/app/plugin-development-alb/4601234567890fd4b2"
  alb_listener_arn = "arn:aws:elasticloadbalancing:eu-central-1:01234567890:listener/app/plugin-development-alb/4601234567890fd4b2/8301234567802db"
  create_ssl       = true # requests ssl for service and attach it to listener rule

  service_domain    = "api-test"
  service_name      = "backend"
  min_service_tasks = 1

  service_image_tag = "nginx:latest"

  service_memory = 512
  service_cpu    = 256
  service_port   = 80
}
