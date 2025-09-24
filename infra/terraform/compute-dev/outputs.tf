output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "control_plane_endpoint" {
  value = aws_lb.cp.dns_name
}

output "cp_asg_name" {
  value = aws_autoscaling_group.cp.name
}

output "wk_asg_name" {
  value = aws_autoscaling_group.wk.name
}

output "teamcity_private_ip" {
  value = aws_instance.teamcity.private_ip
}

output "octopus_private_ip" {
  value = aws_instance.octopus.private_ip
}
