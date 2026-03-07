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

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_profile" {
  type    = string
  default = "dev"
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

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

# ---------------- SES ----------------

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

# ---------------- IAM ----------------

resource "aws_iam_role" "lambda_role" {
  name = "cloudflax-${var.environment}-lambda-role"

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

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_secrets_policy" {
  name = "cloudflax-${var.environment}-lambda-secrets-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_secret.arn
      }
    ]
  })
}

# ---------------- RDS ----------------

resource "aws_rds_cluster" "rds_cluster" {
  cluster_identifier  = "cloudflax-${var.environment}-rds"
  engine              = "aurora-postgresql"
  database_name       = "cloudflax"
  master_username     = var.db_username
  master_password     = var.db_password
  skip_final_snapshot = true
}

resource "aws_rds_cluster_instance" "rds_instance" {
  identifier         = "cloudflax-${var.environment}-rds-instance"
  cluster_identifier = aws_rds_cluster.rds_cluster.id
  instance_class     = "db.t3.micro"
  engine             = aws_rds_cluster.rds_cluster.engine
}

# ---------------- SECRETS ----------------

resource "aws_secretsmanager_secret" "db_secret" {
  name = "cloudflax-${var.environment}-db-secret"
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id = aws_secretsmanager_secret.db_secret.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_rds_cluster.rds_cluster.endpoint
    port     = 5432
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
  function_name    = "cloudflax-${var.environment}-rotation-lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "rotation.handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.rotation_lambda_zip.output_base64sha256

  environment {
    variables = {
      AWS_REGION_NAME = var.aws_region
    }
  }
}

resource "aws_secretsmanager_secret_rotation" "db_rotation" {
  secret_id           = aws_secretsmanager_secret.db_secret.id
  rotation_lambda_arn = aws_lambda_function.rotation_lambda.arn

  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_lambda_permission" "allow_secrets_manager" {
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
  function_name    = "cloudflax-${var.environment}-cleanup-lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "cleanup.handler"
  runtime          = "python3.9"
  source_code_hash = data.archive_file.cleanup_lambda_zip.output_base64sha256

  environment {
    variables = {
      AWS_REGION_NAME = var.aws_region
      DB_SECRET_ARN   = aws_secretsmanager_secret.db_secret.arn
    }
  }
}

resource "aws_cloudwatch_event_rule" "cleanup_schedule" {
  name                = "cloudflax-${var.environment}-cleanup-schedule"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "cleanup_target" {
  rule      = aws_cloudwatch_event_rule.cleanup_schedule.name
  target_id = "CleanupLambda"
  arn       = aws_lambda_function.cleanup_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_cleanup" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cleanup_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cleanup_schedule.arn
}
