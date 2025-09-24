resource "aws_lb" "cp" {
  name               = "${local.name}-cp-nlb"
  load_balancer_type = "network"
  internal           = true
  subnets            = var.private_subnet_ids
  tags               = merge(local.common_tags, { Name = "${local.name}-cp-nlb" })
}

resource "aws_lb_target_group" "cp_6443" {
  name        = "${local.name}-apiserver"
  port        = 6443
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    protocol = "TCP"
    port     = "6443"
  }
  tags = merge(local.common_tags, { Name = "${local.name}-apiserver" })
}

# Automatic register of ASG instances
resource "aws_autoscaling_attachment" "cp_tg" {
  autoscaling_group_name = aws_autoscaling_group.cp.name
  lb_target_group_arn    = aws_lb_target_group.cp_6443.arn
}

resource "aws_lb_listener" "cp_6443" {
  load_balancer_arn = aws_lb.cp.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.cp_6443.arn
  }
}



