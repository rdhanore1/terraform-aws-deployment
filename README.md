# Flask & Express Deployment on AWS (Docker, ECR, ECS, ALB, VPC) with Terraform

This repository demonstrates how to deploy a Flask backend and an Express frontend as Docker containers on AWS using:

- Amazon ECR — Docker image registry
- Amazon VPC — networking layer
- Amazon ECS (Fargate or EC2) — container orchestration
- Application Load Balancer (ALB) — path-based routing
- Terraform — infrastructure as code

The goal is a reproducible, production-capable deployment where:
Users → ALB → ECS Services → Containers (frontend & backend)

---

Table of contents
- Project overview
- Architecture
- Repo layout
- Prerequisites
- Docker: build & push to ECR
- Terraform: backend, variables, apply
- ALB routing & health checks
- Verify deployment
- Recommended production settings
- Troubleshooting
- Example GitHub Actions CI/CD
- License

---

Project overview
This project provisions:
- A VPC with public and private subnets, IGW, route tables
- Security groups for ALB, backend, and frontend
- ECR repositories for flask-backend and express-frontend
- ECS cluster and task definitions (Fargate-optimized by default)
- ECS services for frontend and backend
- Application Load Balancer with path-based routing:
  - /api/* → backend
  - /      → frontend

---

Architecture (high level)
Local Machine
  ├─ Build Docker images
  ├─ Tag images
  └─ Push → AWS ECR

Terraform Creates:
- VPC → Subnets → Routing → Security Groups
- ECR repositories
- ECS Cluster → Task Definitions → Services
- ALB → Target Groups → Listener Routing Rules

Users → ALB DNS → ECS Services → Containers

---

Repo layout
- /backend
  - Dockerfile (Flask app)
  - app files
- /frontend
  - Dockerfile (Express app)
  - app files
- /terraform
  - main.tf, variables.tf, outputs.tf, modules/...
- README.md (this file)

(Adjust paths to your repository structure)

---

Prerequisites
- AWS CLI v2 configured with credentials + region
- Docker (build and push images)
- Terraform v1.3+ (recommended)
- Optional: jq (for scripts)

Example minimum versions:
- aws --version
- docker --version
- terraform -version

---

Build and push Docker images to ECR (example)
1. Create or note the ECR repository URIs produced by Terraform (or create them manually).
   Example ECR URIs:
   - <aws_account_id>.dkr.ecr.<region>.amazonaws.com/flask-backend
   - <aws_account_id>.dkr.ecr.<region>.amazonaws.com/express-frontend

2. Authenticate Docker to ECR:
```bash
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <aws_account_id>.dkr.ecr.<region>.amazonaws.com
```

3. Build, tag, and push backend:
```bash
# Build
docker build -t flask-backend ./backend

# Tag
docker tag flask-backend:latest <aws_account_id>.dkr.ecr.<region>.amazonaws.com/flask-backend:latest

# Push
docker push <aws_account_id>.dkr.ecr.<region>.amazonaws.com/flask-backend:latest
```

4. Build, tag, and push frontend:
```bash
docker build -t express-frontend ./frontend

docker tag express-frontend:latest <aws_account_id>.dkr.ecr.<region>.amazonaws.com/express-frontend:latest

docker push <aws_account_id>.dkr.ecr.<region>.amazonaws.com/express-frontend:latest
```

Notes:
- Use immutable tags (e.g., :v1.0.0, :sha-<short>) in production.
- If using GitHub Actions or CI, authenticate via ECR login and AWS credentials stored in secrets.

---

Terraform: Backend (S3 + DynamoDB) example
For collaborative state, use an S3 backend + DynamoDB lock table. Create a file `backend.tf` (example):

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "terraform/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

Create the S3 bucket and DynamoDB table (manually or via a bootstrap script) before `terraform init`.

---

Terraform: Common workflow
From the terraform directory:
```bash
terraform init
terraform plan -out plan.tfplan
terraform apply "plan.tfplan"
```

To run non-interactively:
```bash
terraform apply -auto-approve
```

Outputs:
- After apply, Terraform should output the ALB DNS name(s).
- Example outputs:
  - frontend_url: http://<alb-dns>
  - backend_url:  http://<alb-dns>/api

---

Terraform variables (example)
Create a `terraform.tfvars` with values appropriate to your account:
```hcl
aws_region       = "us-east-1"
vpc_cidr         = "10.0.0.0/16"
public_subnets   = ["10.0.1.0/24","10.0.2.0/24"]
private_subnets  = ["10.0.3.0/24","10.0.4.0/24"]
cluster_name     = "my-ecs-cluster"
backend_image    = "<aws_account_id>.dkr.ecr.<region>.amazonaws.com/flask-backend:latest"
frontend_image   = "<aws_account_id>.dkr.ecr.<region>.amazonaws.com/express-frontend:latest"
```

Make sure `backend_image` and `frontend_image` point to the images you pushed to ECR.

---

ECS Task Definition notes
- Provide appropriate task IAM roles with only required permissions (e.g., CloudWatch logs).
- Set container port mappings:
  - backend container listens on port 5000 (or your Flask port)
  - frontend container listens on port 3000 (or your Express port)
- Use environment variables or AWS Secrets Manager for sensitive configuration.

---

ALB routing & health checks
- ALB listener on port 80 (or 443 with TLS).
- Two target groups:
  - frontend-target-group: receives / and static routes
  - backend-target-group: receives /api/*

Example ALB rules:
- Rule: If path matches /api/* → forward to backend-target-group
- Default: forward to frontend-target-group

Health check recommendation:
- Path: /health or /api/health (adjust per service)
- Interval: 30s
- Healthy threshold: 2
- Unhealthy threshold: 3
- Timeout: 5s

Make sure your apps expose a lightweight health endpoint returning HTTP 200.

---

Verify deployment
- Get ALB DNS from Terraform outputs.
- Frontend: http://<alb-dns> → should load your frontend app
- Backend: http://<alb-dns>/api → should respond from Flask
- Using curl:
```bash
curl -i http://<alb-dns>/
curl -i http://<alb-dns>/api/health
```

Check ECS console:
- Tasks are running
- Task logs (CloudWatch) contain application startup logs
- ALB target groups show healthy targets

---

Cleanup
To destroy all created infra:
```bash
terraform destroy -auto-approve
```
Be careful: this will remove resources including ECR repos (if not protected), ECS cluster, ALB, and VPC. Clean S3 state and lock table manually if needed.

---

Recommended production settings
- Use Terraform remote state (S3) + DynamoDB locks.
- Use Fargate for serverless container execution (no EC2 to manage).
- Enable HTTPS on ALB with ACM certificates (use a separate Terraform module or request certificate and attach to ALB).
- Use autoscaling (ECS Service Auto Scaling) with CPU/memory or request-based scaling.
- Push images with immutable semantic or commit-based tags and avoid using :latest in production.
- Centralize secrets with AWS Secrets Manager or Parameter Store and grant task role permissions to retrieve secrets.
- Restrict security group egress/ingress to least privilege.

---

Troubleshooting (common issues)
- imagePullBackOff / cannot pull image:
  - Ensure ECR URI is correct and images are pushed.
  - Confirm ECS tasks have VPC endpoints or NAT for ECR (if private subnets) or allow internet access.
- ALB target unhealthy:
  - Confirm correct health check path and container port mapping.
  - Look at application logs to ensure server started successfully.
- Permissions errors:
  - Ensure task execution role can access ECR (ecr:GetAuthorizationToken) and push/pull operations.
- Terraform state locks:
  - Verify DynamoDB table exists for locks and that your backend block is configured properly.

---

Example GitHub Actions CI/CD (build, push, and Terraform apply)
Below is an example workflow. Store AWS credentials (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY) and Terraform cloud/backend credentials in GitHub Secrets. This is an illustrative example — adjust to your security policy.

```yaml
name: ci-cd

on:
  push:
    branches:
      - main

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Build and push backend image
        run: |
          docker build -t flask-backend ./backend
          docker tag flask-backend:latest ${{ secrets.ECR_BACKEND_URI }}:${{ github.sha }}
          docker push ${{ secrets.ECR_BACKEND_URI }}:${{ github.sha }}

      - name: Build and push frontend image
        run: |
          docker build -t express-frontend ./frontend
          docker tag express-frontend:latest ${{ secrets.ECR_FRONTEND_URI }}:${{ github.sha }}
          docker push ${{ secrets.ECR_FRONTEND_URI }}:${{ github.sha }}

      - name: Terraform - init & apply
        working-directory: ./terraform
        env:
          TF_VAR_backend_image: ${{ secrets.ECR_BACKEND_URI }}:${{ github.sha }}
          TF_VAR_frontend_image: ${{ secrets.ECR_FRONTEND_URI }}:${{ github.sha }}
        run: |
          terraform init
          terraform apply -auto-approve
```

Notes:
- Using GitHub Actions to run `terraform apply` requires careful secrets and approval handling in production. Prefer PR-based Terraform runs and manual approvals or use Terraform Cloud/Enterprise.

---

Security considerations
- Do not commit AWS credentials or secrets to Git.
- Limit IAM roles and policies to least privilege.
- Protect S3 state bucket (encrypt, block public access).
- Use HTTPS in production; terminate TLS at the ALB with ACM-managed certificate.

---

Additional resources
- AWS ECS & ECR docs
- Terraform AWS provider docs
- Docker documentation

---

Contributing
Feel free to open issues or pull requests to improve this repo (examples: add CloudWatch log grouping, better Terraform moduleization, or certificate provisioning).

---

License
Specify your license here (e.g., MIT). Update as needed.
