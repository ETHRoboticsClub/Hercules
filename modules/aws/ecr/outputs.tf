output "repository_urls" {
  description = "Map of repository name → URL."
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "github_actions_role_arn" {
  description = "IAM role ARN for GitHub Actions ECR push. Set as AWS_ECR_ROLE_ARN secret in GitHub."
  value       = aws_iam_role.github_actions_ecr.arn
}