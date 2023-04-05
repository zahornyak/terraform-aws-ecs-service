resource "aws_lb_target_group" "service" {
  # if listener arn defined - create target group
  count = var.alb_listener_arn != null ? 1 : 0

  name                 = "alb-${var.environment}-${replace(var.service_name, "_", "")}"
  port                 = var.service_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = data.aws_vpc.this.id
  deregistration_delay = var.deregistration_delay
  health_check {
    enabled             = try(var.health_check.enabled, null)
    interval            = try(var.health_check.interval, null)
    path                = try(var.health_check.path, null)
    timeout             = try(var.health_check.timeout, null)
    healthy_threshold   = try(var.health_check.healthy_threshold, null)
    unhealthy_threshold = try(var.health_check.unhealthy_threshold, null)
    matcher             = try(var.health_check.matcher, null)
  }
}

resource "aws_lb_listener_rule" "service" {
  # if create_envoy is false - create target group
  count = var.alb_listener_arn != null ? 1 : 0

  listener_arn = var.alb_listener_arn

  action {
    type = "forward"
    # if custom target group is not defined - route to service target group
    target_group_arn = var.target_group_arn != null ? var.target_group_arn : aws_lb_target_group.service[0].arn
  }

  condition {
    host_header {
      values = ["${var.service_domain}.${data.aws_route53_zone.this.name}"]
      #      values = [var.listener_host_header]
    }
  }
  depends_on = [aws_lb_target_group.service[0]]
}