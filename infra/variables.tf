variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-west-1"
}

variable "project_name" {
  description = "Used to name and tag all resources"
  type        = string
  default     = "portfolio"
}

variable "domain_name" {
  description = "Route 53 domain (e.g. myportfolio.com) — must already exist in account"
  type        = string
}

variable "app_port" {
  description = "Port FastAPI container listens on"
  type        = number
  default     = 8000
}

variable "github_repo" {
  description = "GitHub repo in owner/repo format (e.g. alice/portfolio)"
  type        = string
}
