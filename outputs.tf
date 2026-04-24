output "cluster_arn" {
  value = data.aws_ecs_cluster.existing.arn
}

output "service_name" {
  value = aws_ecs_service.this.name
}

output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "app_url" {
  value = "https://${var.hostname}"
}

output "jupyter_url" {
  value = "https://${var.hostname}/jupyter"
}

output "efs_file_system_id" {
  value = aws_efs_file_system.this.id
}

output "database_endpoint" {
  value = var.create_database ? aws_rds_cluster.this[0].endpoint : null
}

output "database_port" {
  value = var.create_database ? aws_rds_cluster.this[0].port : null
}

output "database_url" {
  value     = local.database_url
  sensitive = true
}
