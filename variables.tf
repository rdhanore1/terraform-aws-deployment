variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "flask-express-prod"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.50.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default = [
    "10.50.1.0/24",
    "10.50.2.0/24"
  ]
}

# ECR Repositories
variable "repo_backend_name" {
  description = "Backend ECR repo name"
  type        = string
  default     = "flask-backend"
}

variable "repo_frontend_name" {
  description = "Frontend ECR repo name"
  type        = string
  default     = "express-frontend"
}

# Container Ports
variable "flask_container_port" {
  type    = number
  default = 5000
}

variable "express_container_port" {
  type    = number
  default = 3000
}

# ECS Task CPU/Memory
variable "cpu_backend" {
  type    = number
  default = 256
}

variable "memory_backend" {
  type    = number
  default = 512
}

variable "cpu_frontend" {
  type    = number
  default = 256
}

variable "memory_frontend" {
  type    = number
  default = 512
}

# ECS Service Counts
variable "desired_count_backend" {
  type    = number
  default = 1
}

variable "desired_count_frontend" {
  type    = number
  default = 1
}

# Terraform Remote State (optional)
variable "tfstate_bucket" {
  type        = string
  default     = ""
}

variable "tfstate_lock_table" {
  type        = string
  default     = ""
}
