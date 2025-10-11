# Bastion SG 
resource "aws_security_group" "bastion" {
  name        = "${local.name}-bastion-sg"
  description = "Bastion SG"
  vpc_id      = local.vpc_id
  ingress {
    description = "SSH desde tu IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${local.name}-bastion-sg" })
}

# Control-plane SG
resource "aws_security_group" "cp" {
  name        = "${local.name}-cp-sg"
  description = "Control plane"
  vpc_id      = local.vpc_id

  # SSH only from bastion
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # kube-apiserver 6443 from NLB and self (CP)
  ingress {
    from_port = 6443
    to_port   = 6443
    protocol  = "tcp"
    self      = true
  }
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  } # NLB ENIs dentro de la VPC 

  # etcd (CP<->CP)
  ingress {
    from_port = 2379
    to_port   = 2380
    protocol  = "tcp"
    self      = true
  }

  # kubelet in CP (from CP/Workers)
  ingress {
    from_port = 10250
    to_port   = 10250
    protocol  = "tcp"
    self      = true
  }

  # scheduler/controller-manager (CP intern)
  ingress {
    from_port = 10257
    to_port   = 10257
    protocol  = "tcp"
    self      = true
  }
  ingress {
    from_port = 10259
    to_port   = 10259
    protocol  = "tcp"
    self      = true
  }

  # Calico Typha (Worker->CP communication) - moved to separate rule
  # Calico VXLAN overlay (Worker->CP) - moved to separate rule
  # ICMP for debugging (Worker->CP) - moved to separate rule
  # Octopus Tentacle (Octopus->CP communication) - moved to separate rule

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${local.name}-cp-sg" })
}

# Worker SG
resource "aws_security_group" "wk" {
  name        = "${local.name}-wk-sg"
  description = "Workers"
  vpc_id      = local.vpc_id

  # SSH from bastion
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # kubelet 10250 from CP - moved to separate rule
  # Calico VXLAN overlay (CP->Worker) - moved to separate rule
  # ICMP for debugging (CP->Worker) - moved to separate rule

  # All traffic between workers (for Calico pod network)
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  # NodePort range for Kubernetes services (from VPC for ALB access)
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${local.name}-wk-sg" })
}

# CI/CD SG (TeamCity & Octopus, in provate)
resource "aws_security_group" "cicd" {
  name        = "${local.name}-cicd-sg"
  description = "TeamCity/Octopus private"
  vpc_id      = local.vpc_id

  # SSH y UIs only via bastion (port forwarding)
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  } # SSH
  ingress {
    from_port       = 8111
    to_port         = 8111
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  } # TeamCity UI
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    self            = true
  } # Octopus UI (from bastion and other CICD instances) - CP ref moved to separate rule
  ingress {
    from_port       = 10943
    to_port         = 10943
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
    self            = true
  } # Octopus Tentacle Polling (from bastion and other CICD instances) - CP ref moved to separate rule

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "${local.name}-cicd-sg" })
}

# Regla adicional: Workers -> CP API server (6443)
resource "aws_security_group_rule" "wk_to_cp_api" {
  type                     = "ingress"
  from_port                = 6443
  to_port                  = 6443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.wk.id
  security_group_id        = aws_security_group.cp.id
  description              = "Workers to CP API server"
}

# Octopus -> CP Tentacle (Listening mode on port 10933)
resource "aws_security_group_rule" "octopus_to_cp_tentacle" {
  type                     = "ingress"
  from_port                = 10933
  to_port                  = 10933
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cicd.id
  security_group_id        = aws_security_group.cp.id
  description              = "Octopus to CP Tentacle"
}

# BGP rules for Calico
resource "aws_security_group_rule" "cp_bgp_from_workers" {
  type                     = "ingress"
  from_port                = 179
  to_port                  = 179
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.wk.id
  security_group_id        = aws_security_group.cp.id
  description              = "BGP from workers to control plane"
}

resource "aws_security_group_rule" "workers_bgp_from_cp" {
  type                     = "ingress"
  from_port                = 179
  to_port                  = 179
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cp.id
  security_group_id        = aws_security_group.wk.id
  description              = "BGP from control plane to workers"
}

# Circular dependency fixes: Workers -> CP
resource "aws_security_group_rule" "cp_typha_from_workers" {
  type                     = "ingress"
  from_port                = 5473
  to_port                  = 5473
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.wk.id
  security_group_id        = aws_security_group.cp.id
  description              = "Calico Typha from workers to CP"
}

resource "aws_security_group_rule" "cp_vxlan_from_workers" {
  type                     = "ingress"
  from_port                = 4789
  to_port                  = 4789
  protocol                 = "udp"
  source_security_group_id = aws_security_group.wk.id
  security_group_id        = aws_security_group.cp.id
  description              = "Calico VXLAN from workers to CP"
}

resource "aws_security_group_rule" "cp_icmp_from_workers" {
  type                     = "ingress"
  from_port                = -1
  to_port                  = -1
  protocol                 = "icmp"
  source_security_group_id = aws_security_group.wk.id
  security_group_id        = aws_security_group.cp.id
  description              = "ICMP from workers to CP"
}

# Circular dependency fixes: CP -> Workers
resource "aws_security_group_rule" "wk_kubelet_from_cp" {
  type                     = "ingress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cp.id
  security_group_id        = aws_security_group.wk.id
  description              = "Kubelet from CP to workers"
}

resource "aws_security_group_rule" "wk_vxlan_from_cp" {
  type                     = "ingress"
  from_port                = 4789
  to_port                  = 4789
  protocol                 = "udp"
  source_security_group_id = aws_security_group.cp.id
  security_group_id        = aws_security_group.wk.id
  description              = "Calico VXLAN from CP to workers"
}

resource "aws_security_group_rule" "wk_icmp_from_cp" {
  type                     = "ingress"
  from_port                = -1
  to_port                  = -1
  protocol                 = "icmp"
  source_security_group_id = aws_security_group.cp.id
  security_group_id        = aws_security_group.wk.id
  description              = "ICMP from CP to workers"
}

# Circular dependency fixes: CICD -> CP
resource "aws_security_group_rule" "cicd_to_cp_octopus_ui" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cp.id
  security_group_id        = aws_security_group.cicd.id
  description              = "Octopus UI from CP"
}

resource "aws_security_group_rule" "cicd_to_cp_tentacle_polling" {
  type                     = "ingress"
  from_port                = 10943
  to_port                  = 10943
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.cp.id
  security_group_id        = aws_security_group.cicd.id
  description              = "Octopus Tentacle Polling from CP"
}
