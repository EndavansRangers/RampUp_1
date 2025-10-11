# Launch Template CP
resource "aws_launch_template" "cp" {
  name_prefix   = "${local.name}-cp-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.cp_instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = var.nodes_instance_profile_name
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 20
      volume_type = "gp3"
      encrypted   = true
      delete_on_termination = true
    }
  }

  vpc_security_group_ids = [aws_security_group.cp.id]

  user_data = base64encode(templatefile("${path.module}/user-data-cp.sh", {}))

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.name}-cp" })
  }
}


# ASG CP (1 node)
resource "aws_autoscaling_group" "cp" {
  name                      = "${local.name}-cp-asg"
  max_size                  = 1
  min_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = local.private_subnet_ids
  health_check_type         = "EC2"
  launch_template {
    id      = aws_launch_template.cp.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "${local.name}-cp"
    propagate_at_launch = true
  }
  tag {
    key                 = "Project"
    value               = var.project
    propagate_at_launch = true
  }
  tag {
    key                 = "Env"
    value               = var.env
    propagate_at_launch = true
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = true
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }
}

# Launch Template Worker
resource "aws_launch_template" "wk" {
  name_prefix   = "${local.name}-wk-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "c7i-flex.large"  # 2 vCPU, 4GB RAM (upgraded from t3.small)
  key_name      = var.key_name

  iam_instance_profile {
    name = var.nodes_instance_profile_name
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 20
      volume_type = "gp3"
      encrypted   = true
      delete_on_termination = true
    }
  }

  vpc_security_group_ids = [aws_security_group.wk.id]

  user_data = base64encode(templatefile("${path.module}/user-data-wk.sh", {}))

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.name}-wk" })
  }
}

# ASG Worker (0-2 nodes, start at 0 for cost savings)
resource "aws_autoscaling_group" "wk" {
  name                      = "${local.name}-wk-asg"
  max_size                  = 2  # Maximum 2 workers
  min_size                  = 0  # Allow scaling down to 0 when not in use
  desired_capacity          = 0  # Start with 0, manually scale to 2 when needed
  vpc_zone_identifier       = local.private_subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 300  # 5 min grace for worker to join cluster
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
    key                 = "Project"
    value               = var.project
    propagate_at_launch = true
  }
  tag {
    key                 = "Env"
    value               = var.env
    propagate_at_launch = true
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = true
  }
  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }
}
