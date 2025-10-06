output "vpc_id" {
  value       = var.vpc_id
  description = "VPC ID"
}

output "private_subnet_ids" {
  value       = var.private_subnet_ids
  description = "Private subnet IDs"
}

output "public_subnet_ids" {
  value       = var.public_subnet_ids
  description = "Public subnet IDs"
}

output "security_group_bastion_id" {
  value       = aws_security_group.bastion.id
  description = "Security group ID for bastion"
}

output "security_group_cp_id" {
  value       = aws_security_group.cp.id
  description = "Security group ID for control planes"
}

output "security_group_wk_id" {
  value       = aws_security_group.wk.id
  description = "Security group ID for workers"
}

output "asg_cp_name" {
  value       = aws_autoscaling_group.cp.name
  description = "Control plane auto scaling group name"
}

output "asg_wk_name" {
  value       = aws_autoscaling_group.wk.name
  description = "Worker auto scaling group name"
}

output "nlb_dns_name" {
  value       = aws_lb.cp.dns_name
  description = "NLB DNS name for API server"
}

output "nlb_arn" {
  value       = aws_lb.cp.arn
  description = "NLB ARN"
}

output "ssh_proxy_command_example" {
  value       = "ssh -J ubuntu@${aws_instance.bastion.public_ip} ubuntu@<PRIVATE_IP>"
  description = "Example SSH command via bastion jump host"
}

output "kubeconfig_server_url" {
  value       = "https://${aws_lb.cp.dns_name}:6443"
  description = "Server URL to use in kubeconfig"
}

output "next_steps" {
  value = <<-EOT
    
    ╔════════════════════════════════════════════════════════════╗
    ║  Tunefy Production Infrastructure - Next Steps             ║
    ╚════════════════════════════════════════════════════════════╝
    
    1️⃣  SSH to bastion:
       ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.bastion.public_ip}
    
    2️⃣  Get private IPs of control planes:
       aws ec2 describe-instances \
         --filters "Name=tag:Name,Values=${local.name}-cp" \
                   "Name=instance-state-name,Values=running" \
         --query 'Reservations[*].Instances[*].[PrivateIpAddress,InstanceId]' \
         --output table
    
    3️⃣  Update Ansible inventory with IPs:
       infra/ansible/inventories/prod/hosts.ini
    
    4️⃣  Run Ansible to bootstrap Kubernetes HA:
       cd infra/ansible
       ansible-playbook -i inventories/prod/hosts.ini site.yml
    
    5️⃣  After bootstrap, verify cluster:
       kubectl --kubeconfig ~/.kube/config-prod get nodes
    
    📝 Important values:
       - NLB Endpoint: ${aws_lb.cp.dns_name}
       - Bastion IP: ${aws_instance.bastion.public_ip}
       - Cluster Name: ${var.cluster_name}
  EOT
  description = "Next steps after Terraform apply"
}
