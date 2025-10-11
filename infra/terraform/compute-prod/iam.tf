# IAM Policy for SSM Parameter Store access (join command)
resource "aws_iam_policy" "ssm_join_command" {
  name        = "${var.project}-${var.env}-ssm-join-command"
  description = "Allow nodes to read Kubernetes join command from SSM Parameter Store"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/tunefy/${var.env}/k8s/*"
      }
    ]
  })

  tags = local.common_tags
}

# Attach to nodes role (assuming it was created in platform module)
# This is a reference - the actual role should exist
# resource "aws_iam_role_policy_attachment" "nodes_ssm" {
#   role       = var.nodes_role_name
#   policy_arn = aws_iam_policy.ssm_join_command.arn
# }

output "ssm_policy_arn" {
  value       = aws_iam_policy.ssm_join_command.arn
  description = "ARN of SSM policy for join command - attach this to nodes IAM role"
}
