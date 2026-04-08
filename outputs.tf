output "rds_endpoint" {
  description = "Host para conectar a la base de datos (usar en Secrets Manager como 'host')"
  value       = aws_db_instance.rds_instance.address
}

output "rds_port" {
  description = "Puerto de PostgreSQL (usar en Secrets Manager como 'port')"
  value       = aws_db_instance.rds_instance.port
}

output "ses_dkim_records" {
  description = "Registros CNAME de DKIM para verificar el dominio en SES. Agrégalos a tu proveedor de DNS."
  value = [
    for token in aws_sesv2_email_identity.domain.dkim_signing_attributes[0].tokens : {
      type  = "CNAME"
      name  = "${token}._domainkey.${local.ses_domain}"
      value = "${token}.dkim.amazonses.com"
    }
  ]
}

output "send_verify_email_lambda_arn" {
  description = "ARN de la Lambda que envía el correo de verificación vía SES v2 (invócala desde el backend con payload JSON: email, name, link)."
  value       = aws_lambda_function.send_verify_email.arn
}

output "send_verify_email_lambda_name" {
  description = "Nombre de la función Lambda de verificación por correo."
  value       = aws_lambda_function.send_verify_email.function_name
}

output "send_forgot_password_email_lambda_arn" {
  description = "ARN de la Lambda que envía el correo de recuperación de contraseña vía SES v2 (payload JSON: email, name, link, expiresIn)."
  value       = aws_lambda_function.send_forgot_password_email.arn
}

output "send_forgot_password_email_lambda_name" {
  description = "Nombre de la función Lambda de correo de recuperación de contraseña."
  value       = aws_lambda_function.send_forgot_password_email.function_name
}

output "dynamodb_api_throttle_locks_table_name" {
  description = "Nombre de la tabla de throttle (email + rate limit por IP), ej. cloudflax-<env>-api-throttle-locks."
  value       = aws_dynamodb_table.api_throttle_locks.name
}

output "dynamodb_api_throttle_locks_table_arn" {
  description = "ARN de la tabla de throttle."
  value       = aws_dynamodb_table.api_throttle_locks.arn
}

output "dynamodb_table_name" {
  description = "Mismo nombre que dynamodb_api_throttle_locks_table_name (compatibilidad)."
  value       = aws_dynamodb_table.api_throttle_locks.name
}

output "dynamodb_table_arn" {
  description = "Mismo ARN que dynamodb_api_throttle_locks_table_arn (compatibilidad)."
  value       = aws_dynamodb_table.api_throttle_locks.arn
}
