# ============================================
# Cross-Account CI/CD Setup
# ============================================
# TeamCity (Dev) → Push images to ECR (Prod)
# Octopus (Dev) → Deploy via Tentacle (Prod)

# ============================================
# IAM Role for TeamCity (Dev) to push to ECR (Prod)
# ============================================
resource "aws_iam_role" "ecr_push_from_dev" {
  name        = "${local.name}-ecr-push-from-dev"
  description = "Allow TeamCity in Dev account to push images to ECR in Prod"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::638325785916:root"  # Dev account
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "teamcity-tunefy-prod"
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${local.name}-ecr-push-from-dev"
  })
}

# Policy to allow ECR push operations
resource "aws_iam_role_policy" "ecr_push" {
  name = "ecr-push-policy"
  role = aws_iam_role.ecr_push_from_dev.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
        Resource = [
          "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/${var.project}-frontend",
          "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/${var.project}-backend"
        ]
      }
    ]
  })
}

# ============================================
# Octopus Tentacle (Worker) in Prod
# ============================================

# IAM Role for Octopus Tentacle
resource "aws_iam_role" "octopus_tentacle" {
  name               = "${local.name}-octopus-tentacle"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = merge(local.common_tags, { Name = "${local.name}-octopus-tentacle" })
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# SSM for remote access
resource "aws_iam_role_policy_attachment" "tentacle_ssm" {
  role       = aws_iam_role.octopus_tentacle.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ECR Read access (to verify images)
resource "aws_iam_role_policy_attachment" "tentacle_ecr_read" {
  role       = aws_iam_role.octopus_tentacle.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Secrets Manager access for application secrets
resource "aws_iam_role_policy" "tentacle_secrets" {
  name = "secrets-access"
  role = aws_iam_role.octopus_tentacle.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:tunefy-*"
      }
    ]
  })
}

# Custom policy for Kubernetes operations
resource "aws_iam_role_policy" "tentacle_kubernetes" {
  name = "kubernetes-access"
  role = aws_iam_role.octopus_tentacle.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "elasticloadbalancing:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "octopus_tentacle" {
  name = "${local.name}-octopus-tentacle"
  role = aws_iam_role.octopus_tentacle.name
}

# Security Group for Octopus Tentacle
resource "aws_security_group" "octopus_tentacle" {
  name        = "${local.name}-octopus-tentacle-sg"
  description = "Security group for Octopus Tentacle worker"
  vpc_id      = var.vpc_id

  # Octopus Tentacle communication (outbound to Octopus server in Dev)
  # Tentacle in Polling mode initiates connection to Octopus
  # No inbound rules needed for polling mode

  # SSH from bastion for troubleshooting
  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.30.0.0/16"]  # Prod VPC CIDR
  }

  # Allow all outbound
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-octopus-tentacle-sg"
  })
}

# Octopus Tentacle EC2 instance
resource "aws_instance" "octopus_tentacle" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.tentacle_instance_type
  subnet_id                   = var.private_subnet_ids[0]  # First private subnet
  associate_public_ip_address = false
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.octopus_tentacle.name
  vpc_security_group_ids      = [aws_security_group.octopus_tentacle.id]
  
  root_block_device {
    volume_type = "gp3"
    volume_size = 50  # Space for kubectl, packages, logs
    encrypted   = true
    tags        = merge(local.common_tags, { Name = "${local.name}-octopus-tentacle-root" })
  }

  user_data = templatefile("${path.module}/user-data-tentacle-prod.sh", {
    project            = var.project
    env                = var.env
    region             = var.region
    k8s_api_server     = "https://${aws_lb.cp.dns_name}:6443"
    octopus_server_url = var.octopus_server_url
    octopus_api_key    = var.octopus_api_key
    octopus_space      = var.octopus_space
    octopus_environment = "Production"
    octopus_roles      = "k8s-worker,tunefy-prod"
  })
  
  tags = merge(local.common_tags, { 
    Name = "${local.name}-octopus-tentacle"
    Role = "cd-worker"
  })

  lifecycle {
    ignore_changes = [ami, user_data]
  }
}
