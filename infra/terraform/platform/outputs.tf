output "ecr_repo_urls" {
  value = { for k, r in aws_ecr_repository.repos : k => r.repository_url }
}

output "nodes_instance_profile_name" {
  value = aws_iam_instance_profile.nodes.name
}

output "nodes_role_arn" {
  value = aws_iam_role.nodes.arn
}
