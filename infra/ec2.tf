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

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
  }

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

    # Write a systemd service that pulls the latest image from ECR and runs it.
    # Your CI/CD pipeline pushes a new image; this service restarts on reboot
    # and can be triggered manually via: systemctl restart portfolio
    cat > /etc/systemd/system/portfolio.service << 'SERVICE'
    [Unit]
    Description=Portfolio FastAPI app
    After=docker.service network-online.target
    Requires=docker.service

    [Service]
    User=ec2-user
    Restart=always
    RestartSec=5

    # Log in to ECR, pull latest, run
    ExecStartPre=/bin/bash -c 'aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.portfolio.repository_url}'
    ExecStartPre=/usr/bin/docker pull ${aws_ecr_repository.portfolio.repository_url}:latest
    ExecStartPre=-/usr/bin/docker stop portfolio-app
    ExecStartPre=-/usr/bin/docker rm portfolio-app
    ExecStart=/usr/bin/docker run --name portfolio-app \
      --rm \
      -p ${var.app_port}:${var.app_port} \
      -e PORT=${var.app_port} \
      -v /home/ec2-user/data:/data \
      ${aws_ecr_repository.portfolio.repository_url}:latest

    ExecStop=/usr/bin/docker stop portfolio-app

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable portfolio

    # Daily SQLite backup to S3 at 2am
    echo "0 2 * * * ec2-user aws s3 cp /home/ec2-user/data/portfolio.db s3://${aws_s3_bucket.backups.bucket}/backups/portfolio-\$(date +\%Y\%m\%d).db" \
      > /etc/cron.d/portfolio-backup
    chmod 644 /etc/cron.d/portfolio-backup

    # Data directory for SQLite (mounted into the container at /data)
    mkdir -p /home/ec2-user/data
    chown ec2-user:ec2-user /home/ec2-user/data
  USERDATA

  tags = { Name = "${var.project_name}-server" }
}

resource "aws_eip" "portfolio" {
  instance = aws_instance.portfolio.id
  domain   = "vpc"
  tags     = { Name = "${var.project_name}-eip" }
}
