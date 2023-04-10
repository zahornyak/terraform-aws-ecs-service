module "ecs_service" {
  source = "zahornyak/ecs-service/aws"

  region          = "eu-central-1"
  environment     = "production"
  vpc_id          = aws_vpc.main.id
  service_subnets = [aws_subnet.main.id]
  # assign_public_ip = true # if you are using public subnets
  cluster_name     = aws_ecs_cluster.main.name
  route_53_zone_id = aws_route53_zone.primary.zone_id
  alb_arn          = aws_lb.main.arn
  alb_listener_arn = aws_lb_listener.main.arn
  create_ssl       = true # requests ssl for service and attach it to listener rule

  service_domain    = "api"
  service_name      = "backend"
  min_service_tasks = 1

  service_image_tag = "nginx:latest"

  service_memory = 512
  service_cpu    = 256
  service_port   = 80
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
