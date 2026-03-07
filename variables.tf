variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = "" # Dejar vacío si se usan credenciales en .env (AWS_ACCESS_KEY_ID/SECRET)
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "ses_email_identity" {
  type = string
}

variable "db_username" {
  type    = string
  default = "postgres"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_secret_arn" {
  type        = string
  description = "ARN del secreto creado manualmente en AWS Secrets Manager"
}
