output "alb_dns" {
  value = aws_lb.this.dns_name
}

output "ecr_backend_repo" {
  value = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repo" {
  value = aws_ecr_repository.frontend.repository_url
}

output "ecs_cluster" {
  value = aws_ecs_cluster.this.id
}
