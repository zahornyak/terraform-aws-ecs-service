module "records_alb" {
  source  = "registry.terraform.io/terraform-aws-modules/route53/aws//modules/records"
  version = "~> 2.3"

  count = var.alb_listener_arn ? 1 : 0

  zone_id = data.aws_route53_zone.this.id

  records = [
    {
      name = var.service_domain
      type = "A"
      alias = {
        name    = data.aws_alb.this.name
        zone_id = data.aws_alb.this.zone_id
      }
    }
  ]

}