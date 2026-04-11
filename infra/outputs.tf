output "server_instance_id" {
  description = "Shell access: aws ssm start-session --target <value>"
  value       = aws_instance.portfolio.id
}

output "ecr_repository_url" {
  description = "Push your Docker image here: docker push <value>:latest"
  value       = aws_ecr_repository.portfolio.repository_url
}

output "site_url" {
  value = "https://${var.domain_name}"
}

output "cloudfront_domain" {
  description = "Raw CloudFront URL — useful for debugging before DNS propagates"
  value       = "https://${aws_cloudfront_distribution.portfolio.domain_name}"
}

output "media_bucket" {
  value = aws_s3_bucket.media.bucket
}

output "backup_bucket" {
  value = aws_s3_bucket.backups.bucket
}

output "github_actions_role_arn" {
  description = "Set this as the AWS_ROLE_ARN secret in your GitHub repo"
  value       = aws_iam_role.github_actions.arn
}
