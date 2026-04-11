resource "aws_iam_role" "portfolio" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# S3: media uploads + SQLite backups
resource "aws_iam_role_policy" "portfolio_s3" {
  name = "${var.project_name}-s3-policy"
  role = aws_iam_role.portfolio.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.media.arn,
        "${aws_s3_bucket.media.arn}/*",
        aws_s3_bucket.backups.arn,
        "${aws_s3_bucket.backups.arn}/*"
      ]
    }]
  })
}

# ECR: pull images (no push — pushes come from CI/CD pipeline, not the server)
resource "aws_iam_role_policy" "portfolio_ecr" {
  name = "${var.project_name}-ecr-policy"
  role = aws_iam_role.portfolio.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ]
      Resource = "*"
    }]
  })
}

# SSM: shell access with no open ports
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.portfolio.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "portfolio" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.portfolio.name
}
