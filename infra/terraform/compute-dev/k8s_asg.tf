# Launch Template CP
resource "aws_launch_template" "cp" {
  name_prefix   = "${local.name}-cp-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.cp_instance_type
  key_name      = var.key_name
  iam_instance_profile { name = var.nodes_instance_profile_name }
  vpc_security_group_ids = [aws_security_group.cp.id]

  # Cloud-init minimal (hostname); kube* (to do)
  user_data = base64encode(<<EOF
#cloud-config
preserve_hostname: false
hostname: ${local.name}-cp
EOF
  )

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.cp.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, { Name = "${local.name}-cp" })
    }
}


# ASG CP (1 node)
resource "aws_autoscaling_group" "cp" {
  name                      = "${local.name}-cp-asg"
  max_size                  = 1
  min_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = var.private_subnet_ids
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
}

# Launch Template Worker
resource "aws_launch_template" "wk" {
  name_prefix   = "${local.name}-wk-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.wk_instance_type
  key_name      = var.key_name
  iam_instance_profile { name = var.nodes_instance_profile_name }
  vpc_security_group_ids = [aws_security_group.wk.id]
  user_data = base64encode(<<EOF
#cloud-config
preserve_hostname: false
hostname: ${local.name}-wk
EOF
  )
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.wk.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.name}-wk" })
    }
}

# ASG Worker (1 nodo)
resource "aws_autoscaling_group" "wk" {
  name                      = "${local.name}-wk-asg"
  max_size                  = 1
  min_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EC2"
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
}
