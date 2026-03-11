locals {
  ses_domain = split("@", var.ses_email_identity)[1]
}

resource "aws_sesv2_email_identity" "domain" {
  email_identity = local.ses_domain
}

resource "aws_ses_configuration_set" "default" {
  name = "cloudflax-${var.environment}-config-set"
}

resource "aws_ses_template" "auth_verify_email" {
  name    = "auth-verify-email"
  subject = "Verify your account, {{name}}"
  html    = file("${path.module}/templates/auth-verify-email.html")
  text    = file("${path.module}/templates/auth-verify-email.txt")
}
