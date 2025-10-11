# ============================================
# Control Plane Auto Scaling Group (1 node for Free Tier)
# ============================================

resource "aws_launch_template" "cp" {
  name_prefix   = "${local.name}-cp-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.cp_instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = var.nodes_instance_profile_name
  }

  vpc_security_group_ids = [aws_security_group.cp.id]

  # Complete Kubernetes setup with user data
  user_data = base64encode(templatefile("${path.module}/user-data-cp-prod.sh", {
    cluster_name = var.cluster_name
    pod_cidr     = "192.168.0.0/16"
    region       = var.region
  }))

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 30  # Optimized for Free Tier
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name                                        = "${local.name}-cp"
      Role                                        = "control-plane"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${local.name}-cp-volume"
    })
  }
}

resource "aws_autoscaling_group" "cp" {
  name                      = "${local.name}-cp-asg"
  max_size                  = 1
  min_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.cp.id
    version = "$Latest"
  }

  # Attach to NLB target group
  target_group_arns = [aws_lb_target_group.cp_6443.arn]

  tag {
    key                 = "Name"
    value               = "${local.name}-cp"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "control-plane"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ============================================
# Worker Auto Scaling Group (2 nodes for Free Tier)
# ============================================

resource "aws_launch_template" "wk" {
  name_prefix   = "${local.name}-wk-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.wk_instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = var.nodes_instance_profile_name
  }

  vpc_security_group_ids = [aws_security_group.wk.id]

  # Complete Kubernetes worker setup with auto-join
  user_data = base64encode(templatefile("${path.module}/user-data-wk-prod.sh", {
    cluster_name = var.cluster_name
    region       = var.region
  }))

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 30  # Optimized for Free Tier
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name                                        = "${local.name}-wk"
      Role                                        = "worker"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${local.name}-wk-volume"
    })
  }
}

resource "aws_autoscaling_group" "wk" {
  name                      = "${local.name}-wk-asg"
  max_size                  = 4  # Allow scaling up if needed
  min_size                  = 2
  desired_capacity          = 2
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.wk.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-wk"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = false
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = false
  }

  lifecycle {
    create_before_destroy = true
  }
}
