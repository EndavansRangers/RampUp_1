resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.bastion_instance_type
  subnet_id                   = var.public_subnet_ids[0]
  associate_public_ip_address = true
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.bastion.id]

  root_block_device {
    volume_size           = 8 # Minimal size for Free Tier
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    
    # Update system
    apt-get update
    apt-get upgrade -y
    
    # Install useful tools
    apt-get install -y \
      curl \
      wget \
      vim \
      htop \
      jq \
      awscli
    
    # Configure SSH banner
    echo "
    ╔════════════════════════════════════════╗
    ║  Tunefy Production Bastion Host        ║
    ║  Environment: PRODUCTION               ║
    ║  ⚠️  UNAUTHORIZED ACCESS PROHIBITED     ║
    ╚════════════════════════════════════════╝
    " > /etc/motd
    
    # Set hostname
    hostnamectl set-hostname ${local.name}-bastion
  EOF

  tags = merge(local.common_tags, {
    Name = "${local.name}-bastion"
    Role = "bastion"
  })
}

output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "Public IP of bastion host for SSH access"
}

output "bastion_ssh_command" {
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.bastion.public_ip}"
  description = "SSH command to connect to bastion"
}
