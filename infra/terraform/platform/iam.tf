data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "nodes" {
  name               = "${local.name}-nodes"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = merge(local.common_tags, { Name = "${local.name}-nodes" })
}

# minimal admin policies (SSM + ECR Read)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "nodes" {
  name = "${local.name}-nodes"
  role = aws_iam_role.nodes.name
  tags = merge(local.common_tags, { Name = "${local.name}-nodes" })
}

# LBC: ELB y EC2
resource "aws_iam_role_policy_attachment" "nodes_elb_full" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
}
resource "aws_iam_role_policy_attachment" "nodes_ec2_read" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

# ExternalDNS: Route53
resource "aws_iam_role_policy_attachment" "nodes_route53_full" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRoute53FullAccess"
}

# CSI provider AWS (Secret Manager/KMS) – simplificado
resource "aws_iam_role_policy_attachment" "nodes_secrets_manager_read" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

# AWS Load Balancer Controller - Política personalizada para permisos EC2 faltantes
data "aws_iam_policy_document" "alb_controller_ec2" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeSecurityGroups",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:DescribeInstances",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeNetworkInterfaces",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DescribeTags"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "alb_controller_ec2" {
  name        = "${local.name}-alb-controller-ec2"
  description = "Additional EC2 permissions required by AWS Load Balancer Controller"
  policy      = data.aws_iam_policy_document.alb_controller_ec2.json
  tags        = merge(local.common_tags, { Name = "${local.name}-alb-controller-ec2" })
}

resource "aws_iam_role_policy_attachment" "nodes_alb_controller_ec2" {
  role       = aws_iam_role.nodes.name
  policy_arn = aws_iam_policy.alb_controller_ec2.arn
}