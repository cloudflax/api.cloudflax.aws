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
