# IAM Policy for K8s nodes to read/write join command from SSM Parameter Store
# This allows:
# - Control Plane: Write join command to SSM
# - Worker nodes: Read join command from SSM to auto-join

resource "aws_iam_policy" "ssm_join_command" {
  name        = "${local.name}-ssm-join-command"
  description = "Allow K8s nodes to read/write join command from SSM Parameter Store"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:PutParameter"
        ]
        Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/tunefy/${var.env}/k8s/*"
      }
    ]
  })
  
  tags = local.common_tags
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Output for reference
output "ssm_policy_arn" {
  value       = aws_iam_policy.ssm_join_command.arn
  description = "ARN of the SSM policy for K8s join command - attach this to tunefy-dev-nodes role manually"
}
