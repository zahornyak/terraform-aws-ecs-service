data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_route53_zone" "this" {
  zone_id = var.route_53_zone_id
}

data "aws_alb" "this" {
  arn = var.alb_arn
}
