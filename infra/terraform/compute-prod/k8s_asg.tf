# ============================================
# Control Plane Auto Scaling Group (3 nodes)
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

  # User data for hostname setup
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euo pipefail
    
    # Set hostname
    INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
    hostnamectl set-hostname ${local.name}-cp-$INSTANCE_ID
    
    # Update /etc/hosts
    echo "127.0.0.1 ${local.name}-cp-$INSTANCE_ID" >> /etc/hosts
  EOF
  )

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 40 # For etcd + system
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name                                    = "${local.name}-cp"
      Role                                    = "control-plane"
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
  name                = "${local.name}-cp-asg"
  max_size            = 3
  min_size            = 3
  desired_capacity    = 3
  vpc_zone_identifier = var.private_subnet_ids
  health_check_type   = "EC2"
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
# Worker Auto Scaling Group (3 nodes, scalable to 6)
# ============================================

# User data script for automatic join
locals {
  worker_userdata = <<-EOT
    #!/bin/bash
    set -euo pipefail
    
    # Log everything
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    
    echo "========================================="
    echo "🚀 Starting Kubernetes Worker Bootstrap"
    echo "========================================="
    
    # Wait for cloud-init to complete
    echo "⏳ Waiting for cloud-init..."
    cloud-init status --wait
    
    # Set hostname
    INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
    hostnamectl set-hostname ${var.cluster_name}-wk-$INSTANCE_ID
    echo "✅ Hostname set to: ${var.cluster_name}-wk-$INSTANCE_ID"
    
    # Install AWS CLI if not present
    if ! command -v aws &> /dev/null; then
      echo "📦 Installing AWS CLI..."
      apt-get update
      apt-get install -y awscli
    fi
    
    # Wait for SSM parameter to be available (in case cluster is still bootstrapping)
    echo "⏳ Waiting for join command in SSM Parameter Store..."
    RETRIES=0
    MAX_RETRIES=30
    while [ $RETRIES -lt $MAX_RETRIES ]; do
      if aws ssm get-parameter \
        --name "/tunefy/prod/k8s/join-command" \
        --region ${var.region} \
        --query "Parameter.Value" \
        --output text &> /dev/null; then
        echo "✅ Join command found!"
        break
      fi
      
      RETRIES=$((RETRIES+1))
      echo "⏳ Retry $RETRIES/$MAX_RETRIES..."
      sleep 10
    done
    
    if [ $RETRIES -eq $MAX_RETRIES ]; then
      echo "❌ ERROR: Join command not found in SSM after $MAX_RETRIES retries"
      echo "⚠️  This instance will NOT join the cluster automatically"
      exit 1
    fi
    
    # Retrieve join command
    echo "📥 Retrieving join command from SSM..."
    JOIN_CMD=$(aws ssm get-parameter \
      --name "/tunefy/prod/k8s/join-command" \
      --with-decryption \
      --query "Parameter.Value" \
      --output text \
      --region ${var.region})
    
    if [ -z "$JOIN_CMD" ]; then
      echo "❌ ERROR: Join command is empty"
      exit 1
    fi
    
    echo "🔗 Joining Kubernetes cluster..."
    eval "$JOIN_CMD"
    
    # Verify kubelet is running
    echo "🔍 Verifying kubelet status..."
    sleep 5
    if systemctl is-active --quiet kubelet; then
      echo "✅ Kubelet is running!"
      systemctl status kubelet --no-pager
    else
      echo "⚠️  WARNING: Kubelet is not running"
      systemctl status kubelet --no-pager
      exit 1
    fi
    
    echo "========================================="
    echo "✅ Worker node joined successfully!"
    echo "========================================="
  EOT
}

resource "aws_launch_template" "wk" {
  name_prefix   = "${local.name}-wk-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.wk_instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = var.nodes_instance_profile_name
  }

  vpc_security_group_ids = [aws_security_group.wk.id]

  # Bootstrap script for auto-join
  user_data = base64encode(local.worker_userdata)

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20 # Reduced for Free Tier
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name                                    = "${local.name}-wk"
      Role                                    = "worker"
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
  name                = "${local.name}-wk-asg"
  max_size            = 6  # Allow scaling up
  min_size            = 3
  desired_capacity    = 3
  vpc_zone_identifier = var.private_subnet_ids
  health_check_type   = "EC2"
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
