# Portfolio Infrastructure (OpenTofu)

~$3–5/month AWS stack running a FastAPI app in Docker.

## How deploys work

1. CI/CD pipeline builds Docker image and pushes it to ECR
2. Trigger a restart on the server: `systemctl restart portfolio`
3. The systemd service pulls the new image from ECR and starts it

## Prerequisites

- Session Manager
  - https://docs.aws.amazon.com/systems-manager/latest/userguide/install-plugin-debian-and-ubuntu.html
  - To uninstall in the future: `sudo dpkg -r session-manager-plugin`

## First deploy (after tofu apply)

```bash
# 1. Authenticate Docker to ECR
aws ecr get-login-password --region us-west-1 \
  | docker login --username AWS --password-stdin $(tofu output -raw ecr_repository_url)

# 2. Build and push your image
docker build --platform linux/arm64 -t portfolio .
docker tag portfolio:latest $(tofu output -state=infra/terraform.tfstate -raw ecr_repository_url):latest
docker push $(tofu output -state=infra/terraform.tfstate -raw ecr_repository_url):latest

# 3. Open a session on the server and start the service
aws ssm start-session --target $(tofu output -state=infra/terraform.tfstate -raw server_instance_id)
# Inside the session:
sudo systemctl start portfolio
```

## Subsequent deploys (CI/CD)

Your pipeline only needs to:

```bash
# Build and push
docker build --platform linux/arm64 -t portfolio .
docker tag portfolio $(tofu output -raw ecr_repository_url):latest
docker push $(tofu output -raw ecr_repository_url):latest

# Restart the service on the server via SSM (no SSH needed)
aws ssm send-command \
  --instance-ids $(tofu output -raw server_instance_id) \
  --document-name "AWS-RunShellScript" \
  --parameters commands=["sudo systemctl restart portfolio"]
```

## SQLite database

The container mounts `/home/ec2-user/data` at `/data` inside the container.
Point your FastAPI app at `/data/portfolio.db` for the SQLite file.

## FastAPI Dockerfile example

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Teardown

```bash
tofu destroy
```
