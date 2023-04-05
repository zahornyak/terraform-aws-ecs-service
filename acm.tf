module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 3.3.0"
  count   = var.create_ssl ? 1 : 0

  domain_name = "${var.service_domain}.${data.aws_route53_zone.this.name}"
  zone_id     = data.aws_route53_zone.this.zone_id

  wait_for_validation = true

}

resource "aws_lb_listener_certificate" "this" {
  count = var.create_ssl ? 1 : 0

  listener_arn    = var.alb_listener_arn
  certificate_arn = module.acm[0].acm_certificate_arn
}