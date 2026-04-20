data "aws_ami" "al2023_arm" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "portfolio" {
  ami                    = data.aws_ami.al2023_arm.id
  instance_type          = "t4g.nano"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.portfolio.id]
  iam_instance_profile   = aws_iam_instance_profile.portfolio.name

  user_data = <<-USERDATA
    #!/bin/bash
    set -e
    dnf update -y

    # Docker
    dnf install -y docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user

    # SSM agent (pre-installed on AL2023, just ensure it's running)
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent

    # Data directory for SQLite (mounted into the container at /data)
    mkdir -p /home/ec2-user/data
    chown ec2-user:ec2-user /home/ec2-user/data

    # Daily SQLite backup to S3 at 2am
    dnf install -y cronie
    systemctl enable crond
    systemctl start crond
    echo "0 2 * * * ec2-user aws s3 cp /home/ec2-user/data/portfolio.db s3://${aws_s3_bucket.backups.bucket}/backups/portfolio-\$(date +\%Y\%m\%d).db" \
      > /etc/cron.d/portfolio-backup
    chmod 644 /etc/cron.d/portfolio-backup

    # ── Portfolio app ─────────────────────────────────────────────────────────
    # Write a startup script that pulls and runs the app container.
    # On first boot this may fail if no image has been pushed yet — that's fine,
    # the GitHub Actions pipeline will start the container on the first deploy.
    cat > /usr/local/bin/start-portfolio.sh << 'SCRIPT'
    #!/bin/bash
    aws ecr get-login-password --region ${var.aws_region} \
      | docker login --username AWS --password-stdin ${aws_ecr_repository.portfolio.repository_url}

    # Pull latest — exit gracefully if the image doesn't exist yet
    docker pull ${aws_ecr_repository.portfolio.repository_url}:latest || {
      echo "No image in ECR yet — the container will start on the first deploy."
      exit 0
    }

    # Stop and remove any existing container
    docker stop portfolio-app 2>/dev/null || true
    docker rm   portfolio-app 2>/dev/null || true

    docker run -d \
      --name portfolio-app \
      --restart unless-stopped \
      -p ${var.app_port}:${var.app_port} \
      -e PORT=${var.app_port} \
      -v /home/ec2-user/data:/data \
      ${aws_ecr_repository.portfolio.repository_url}:latest
    SCRIPT

    chmod +x /usr/local/bin/start-portfolio.sh

    # Systemd service — runs the startup script on every boot
    cat > /etc/systemd/system/portfolio.service << 'SERVICE'
    [Unit]
    Description=Portfolio FastAPI app
    After=docker.service network-online.target
    Requires=docker.service

    [Service]
    Type=oneshot
    RemainAfterExit=yes
    ExecStart=/usr/local/bin/start-portfolio.sh

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable portfolio
    systemctl start portfolio
  USERDATA

  tags = { Name = "${var.project_name}-server" }
}

resource "aws_eip" "portfolio" {
  instance = aws_instance.portfolio.id
  domain   = "vpc"
  tags     = { Name = "${var.project_name}-eip" }
}
