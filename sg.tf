module "service_container_sg" {
  source  = "registry.terraform.io/terraform-aws-modules/security-group/aws"
  version = "~> 4.3"

  name        = "${var.environment}-service-container-sg"
  description = "Security group for ${var.environment} backend Container"
  vpc_id      = var.vpc_id

  ingress_with_cidr_blocks = [
    {
      from_port   = var.service_port
      to_port     = var.service_port
      protocol    = "tcp"
      description = "${var.service_name} service port"
      cidr_blocks = data.aws_vpc.this.cidr_block
  }]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]


}
