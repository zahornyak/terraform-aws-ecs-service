# Minimum ECS service (no load balancer)

Smallest working setup: Fargate service with one container, no ALB, DNS, or SSL.

```hcl
module "ecs_service" {
  source = "zahornyak/ecs-service/aws"

  environment     = "dev"
  vpc_id          = "vpc-xxxxxxxx"
  service_subnets = ["subnet-aaaaaaaa", "subnet-bbbbbbbb"]
  cluster_name    = "dev-cluster"

  service_name   = "worker"
  service_cpu    = 256
  service_memory = 512
  desired_count  = 1

  container_definitions = {
    app = {
      container_image = "public.ecr.aws/nginx/nginx:latest"
      container_name  = "app"
      containerPort   = 80
    }
  }
}
```

Set `assign_public_ip = true` if the subnets are public.
