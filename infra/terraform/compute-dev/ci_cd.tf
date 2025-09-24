# IAM  TeamCity (SSM + ECR PowerUser)
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "teamcity" {
  name               = "${local.name}-teamcity"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = merge(local.common_tags, { Name = "${local.name}-teamcity" })
}

resource "aws_iam_role_policy_attachment" "tc_ssm" {
  role       = aws_iam_role.teamcity.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy_attachment" "tc_ecr_power" {
  role       = aws_iam_role.teamcity.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
}
resource "aws_iam_instance_profile" "teamcity" {
  name = "${local.name}-teamcity"
  role = aws_iam_role.teamcity.name
}

# Octopus (only SSM)
resource "aws_iam_role" "octopus" {
  name               = "${local.name}-octopus"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = merge(local.common_tags, { Name = "${local.name}-octopus" })
}
resource "aws_iam_role_policy_attachment" "oc_ssm" {
  role       = aws_iam_role.octopus.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "octopus" {
  name = "${local.name}-octopus"
  role = aws_iam_role.octopus.name
}

# TeamCity in private subnet
resource "aws_instance" "teamcity" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.tc_instance_type
  subnet_id              = var.private_subnet_ids[0]
  associate_public_ip_address = false
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.teamcity.name
  vpc_security_group_ids = [aws_security_group.cicd.id]
  tags = merge(local.common_tags, { Name = "${local.name}-teamcity" })
}

# Octopus in private subnet
resource "aws_instance" "octopus" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.oc_instance_type
  subnet_id              = var.private_subnet_ids[0]
  associate_public_ip_address = false
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.octopus.name
  vpc_security_group_ids = [aws_security_group.cicd.id]
  tags = merge(local.common_tags, { Name = "${local.name}-octopus" })
}

