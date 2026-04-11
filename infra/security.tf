resource "aws_security_group" "portfolio" {
  name        = "${var.project_name}-sg"
  description = "Portfolio server: app port open to world; no SSH (use SSM)"
  vpc_id      = aws_vpc.main.id

  # FastAPI port — CloudFront hits this
  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg" }
}
