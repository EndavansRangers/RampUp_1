# Network Load Balancer for Kubernetes API Server (internal)
resource "aws_lb" "cp" {
  name               = "${local.name}-cp-nlb"
  load_balancer_type = "network"
  internal           = true
  subnets            = var.private_subnet_ids

  enable_cross_zone_load_balancing = true

  tags = merge(local.common_tags, {
    Name = "${local.name}-cp-nlb"
  })
}

# Target Group for API Server (port 6443)
resource "aws_lb_target_group" "cp_6443" {
  name        = "${local.name}-apiserver"
  port        = 6443
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  deregistration_delay = 30 # Fast draining for HA

  health_check {
    protocol            = "TCP"
    port                = "6443"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-apiserver-tg"
  })
}

# Listener for port 6443
resource "aws_lb_listener" "cp_6443" {
  load_balancer_arn = aws_lb.cp.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cp_6443.arn
  }
}

output "control_plane_endpoint" {
  value       = aws_lb.cp.dns_name
  description = "Internal NLB DNS name for Kubernetes API server (use in kubeconfig)"
}

output "control_plane_endpoint_url" {
  value       = "https://${aws_lb.cp.dns_name}:6443"
  description = "Full URL for Kubernetes API server"
}
