terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# 🔥 MODO MOTO
variable "use_moto" {
  type    = bool
  default = true
}

variable "ses_email_identity" {
  type = string
}

provider "aws" {
  access_key = "test"
  secret_key = "test"
  region     = "us-east-1"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  s3_use_path_style = true

  endpoints {
    ses            = "http://localhost:5000"
    sesv2          = "http://localhost:5000"
    rds            = "http://localhost:5000"
    secretsmanager = "http://localhost:5000"
    sts            = "http://localhost:5000"
    iam            = "http://localhost:5000"
    lambda         = "http://localhost:5000"
    events         = "http://localhost:5000"
    cloudwatch     = "http://localhost:5000"
  }
}

# ---------------- SES (Moto) ----------------

resource "aws_ses_email_identity" "from_email" {
  email = var.ses_email_identity
}

resource "aws_ses_configuration_set" "default" {
  name = "local-config-set"
}

resource "aws_ses_template" "auth_verify_email" {
  name    = "auth-verify-email"
  subject = "Verify your account, {{name}}"
  html    = file("${path.module}/templates/auth-verify-email.html")
  text    = file("${path.module}/templates/auth-verify-email.txt")
}

# ---------------- IAM ----------------

resource "aws_iam_role" "lambda_role" {
  name = "rotation_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# ---------------- RDS (desactivado en modo Moto) ----------------

resource "aws_rds_cluster" "local_rds_cluster" {
  count = var.use_moto ? 0 : 1

  cluster_identifier  = "tf-local-rds"
  engine              = "aurora-postgresql"
  database_name       = "cloudflax"
  master_username     = "postgres"
  master_password     = "password"
  skip_final_snapshot = true
}

resource "aws_rds_cluster_instance" "local_rds_instance" {
  count = var.use_moto ? 0 : 1

  identifier         = "tf-local-rds-instance"
  cluster_identifier = aws_rds_cluster.local_rds_cluster[0].id
  instance_class     = "db.t3.micro"
  engine             = aws_rds_cluster.local_rds_cluster[0].engine
}

# ---------------- SECRETS ----------------

resource "aws_secretsmanager_secret" "db_secret" {
  name = "tf-local-db-secret"
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = aws_secretsmanager_secret.db_secret.id

  secret_string = jsonencode({
    username = "postgres"
    password = "password"
    host     = "host.docker.internal"
    port     = 4510
    dbname   = "cloudflax"
  })
}

# ---------------- ROTATION LAMBDA ----------------

data "archive_file" "rotation_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/db_rotation"
  output_path = "${path.module}/lambda/db_rotation/rotation_code.zip"
}

resource "aws_lambda_function" "rotation_lambda" {
  filename         = data.archive_file.rotation_lambda_zip.output_path
  function_name    = "tf-rotation-lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "rotation.handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.rotation_lambda_zip.output_base64sha256

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "http://host.docker.internal:5000"
    }
  }
}

# ❌ NO ROTATION EN MOTO
resource "aws_secretsmanager_secret_rotation" "db_rotation" {
  count = var.use_moto ? 0 : 1

  secret_id           = aws_secretsmanager_secret.db_secret.id
  rotation_lambda_arn = aws_lambda_function.rotation_lambda.arn

  rotation_rules {
    automatically_after_days = 30
  }
}

# ❌ NO LAMBDA PERMISSION EN MOTO
resource "aws_lambda_permission" "allow_secrets_manager" {
  count = var.use_moto ? 0 : 1

  statement_id  = "AllowExecutionFromSecretsManager"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotation_lambda.function_name
  principal     = "secretsmanager.amazonaws.com"
}

# ---------------- CLEANUP LAMBDA ----------------

data "archive_file" "cleanup_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/cleanup_tokens"
  output_path = "${path.module}/lambda/cleanup_tokens/cleanup_code.zip"
}

resource "aws_lambda_function" "cleanup_lambda" {
  filename         = data.archive_file.cleanup_lambda_zip.output_path
  function_name    = "tf-cleanup-lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "cleanup.handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleanup_lambda_zip.output_base64sha256

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "http://host.docker.internal:5000"
      DB_SECRET_ARN            = aws_secretsmanager_secret.db_secret.arn
    }
  }
}

# ❌ EVENTBRIDGE DESACTIVADO EN MOTO
resource "aws_cloudwatch_event_rule" "cleanup_schedule" {
  count = var.use_moto ? 0 : 1

  name                = "cleanup-every-minute"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "cleanup_target" {
  count = var.use_moto ? 0 : 1

  rule      = aws_cloudwatch_event_rule.cleanup_schedule[0].name
  target_id = "CleanupLambda"
  arn       = aws_lambda_function.cleanup_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_cleanup" {
  count = var.use_moto ? 0 : 1

  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cleanup_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cleanup_schedule[0].arn
}