resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = var.public_subnet_ids[0]
  associate_public_ip_address = true
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]

  tags = merge(local.common_tags, { Name = "${local.name}-bastion" })
}

output "bastion_public_ip" { value = aws_instance.bastion.public_ip }
