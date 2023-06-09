```hcl
module "ecs_service" {
  source = "zahornyak/ecs-service/aws"

  environment     = "production"
  vpc_id          = aws_vpc.main.id
  vpc_cidr_block  = aws_vpc.main.cidr_block # use when you dont have previously created vpc
  service_subnets = [aws_subnet.main.id]
  # assign_public_ip = true # if you are using public subnets
  cluster_name       = aws_ecs_cluster.main.name
  route_53_zone_id   = aws_route53_zone.primary.id
  route_53_zone_name = aws_route53_zone.primary.name # use when you dont have previously created Route53 zone
  lb_arn             = aws_lb.main.arn
  lb_listener_arn    = aws_lb_listener.main.arn
  lb_dns_name        = aws_lb.main.dns_name # use when you dont have previously created load balancer
  create_ssl         = true                 # requests ssl for service and attach it to listener rule

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
      ssm_env_file = "./.env"
    }
  }



  service_memory = 1024
  service_cpu    = 512
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_route53_zone" "primary" {
  name = "example.com"
}

resource "aws_lb" "main" {
  name               = "test-lb-tf"
  load_balancer_type = "application"

  # Some configs ..

}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}


resource "aws_ecs_cluster" "main" {
  name = "main"
}
```