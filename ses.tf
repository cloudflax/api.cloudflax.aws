resource "aws_ses_email_identity" "from_email" {
  email = var.ses_email_identity
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
