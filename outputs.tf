output "rds_endpoint" {
  description = "Host para conectar a la base de datos (usar en Secrets Manager como 'host')"
  value       = aws_db_instance.rds_instance.address
}

output "rds_port" {
  description = "Puerto de PostgreSQL (usar en Secrets Manager como 'port')"
  value       = aws_db_instance.rds_instance.port
}
