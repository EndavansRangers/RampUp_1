# Security Group for Bastion
resource "aws_security_group" "bastion" {
  name        = "${local.name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = var.vpc_id

  # SSH from allowed CIDR (your IP)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "SSH from allowed IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-bastion-sg"
  })
}

# Security Group for NLB (for health checks to CPs)
resource "aws_security_group" "nlb" {
  name        = "${local.name}-nlb-sg"
  description = "Security group for NLB to control plane"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${local.name}-nlb-sg"
  })
}

# NLB egress to CP (separate rule to avoid cycle)
resource "aws_security_group_rule" "nlb_to_cp" {
  type                     = "egress"
  from_port                = 6443
  to_port                  = 6443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cp.id
  security_group_id        = aws_security_group.nlb.id
  description              = "Health check to API server"
}

# Security Group for Control Plane nodes
resource "aws_security_group" "cp" {
  name        = "${local.name}-cp-sg"
  description = "Security group for Kubernetes control plane nodes"
  vpc_id      = var.vpc_id

  # SSH from bastion
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description     = "SSH from bastion"
  }

  # API Server from NLB
  ingress {
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    security_groups = [aws_security_group.nlb.id]
    description     = "API server from NLB"
  }

  # API Server from other CPs (HA)
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    self        = true
    description = "API server between control planes"
  }

  # etcd cluster (2379-2380)
  ingress {
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    self        = true
    description = "etcd cluster communication"
  }

  # Kubelet API (self)
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
    description = "Kubelet API between CPs"
  }

  # Controller Manager
  ingress {
    from_port   = 10257
    to_port     = 10257
    protocol    = "tcp"
    self        = true
    description = "Controller Manager"
  }

  # Scheduler
  ingress {
    from_port   = 10259
    to_port     = 10259
    protocol    = "tcp"
    self        = true
    description = "Scheduler"
  }

  # Calico BGP (if using BGP mode)
  ingress {
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    self        = true
    description = "Calico BGP"
  }

  # VXLAN for Calico
  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    self        = true
    description = "Calico VXLAN"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-cp-sg"
  })
}

# Security Group for Worker nodes
resource "aws_security_group" "wk" {
  name        = "${local.name}-wk-sg"
  description = "Security group for Kubernetes worker nodes"
  vpc_id      = var.vpc_id

  # SSH from bastion
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    description     = "SSH from bastion"
  }

  # Kubelet API between workers
  ingress {
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    self        = true
    description = "Kubelet API between workers"
  }

  # NodePort Services (30000-32767)
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    self        = true
    description = "NodePort services"
  }

  # Calico VXLAN
  ingress {
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    self        = true
    description = "Calico VXLAN between workers"
  }

  # Calico BGP
  ingress {
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    self        = true
    description = "Calico BGP between workers"
  }

  # Allow traffic from ALB (for Ingress)
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ALB has dynamic IPs
    description = "Traffic from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-wk-sg"
  })
}

# --- Separate rules to avoid circular dependencies ---

# CP: Allow API server from workers
resource "aws_security_group_rule" "cp_api_from_wk" {
  type                     = "ingress"
  from_port                = 6443
  to_port                  = 6443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.wk.id
  security_group_id        = aws_security_group.cp.id
  description              = "API server from workers"
}

# CP: Allow Kubelet API from workers
resource "aws_security_group_rule" "cp_kubelet_from_wk" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.wk.id
  security_group_id        = aws_security_group.cp.id
  description              = "Kubelet API from workers"
}

# CP: Allow VXLAN from workers
resource "aws_security_group_rule" "cp_vxlan_from_wk" {
  type                     = "ingress"
  from_port                = 4789
  to_port                  = 4789
  protocol                 = "udp"
  source_security_group_id = aws_security_group.wk.id
  security_group_id        = aws_security_group.cp.id
  description              = "Calico VXLAN from workers"
}

# WK: Allow Kubelet API from CPs
resource "aws_security_group_rule" "wk_kubelet_from_cp" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cp.id
  security_group_id        = aws_security_group.wk.id
  description              = "Kubelet API from CPs"
}

# WK: Allow VXLAN from CPs
resource "aws_security_group_rule" "wk_vxlan_from_cp" {
  type                     = "ingress"
  from_port                = 4789
  to_port                  = 4789
  protocol                 = "udp"
  source_security_group_id = aws_security_group.cp.id
  security_group_id        = aws_security_group.wk.id
  description              = "Calico VXLAN from CPs"
}
