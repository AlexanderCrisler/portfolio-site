# ── ECR repository — CI/CD pipeline pushes images here ──────────────────
resource "aws_ecr_repository" "portfolio" {
  name                 = var.project_name
  image_tag_mutability = "MUTABLE"   # Allows overwriting the 'latest' tag

  image_scanning_configuration {
    scan_on_push = true              # Free basic vulnerability scanning on every push
  }

  tags = { Name = "${var.project_name}-ecr" }
}

# Keep only the 10 most recent images — avoids storage costs accumulating
resource "aws_ecr_lifecycle_policy" "portfolio" {
  repository = aws_ecr_repository.portfolio.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
