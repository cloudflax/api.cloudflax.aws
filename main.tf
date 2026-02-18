terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider configured for LocalStack
# Provider configurado para LocalStack
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
    rds            = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    sts            = "http://localhost:4566"
    iam            = "http://localhost:4566"
    lambda         = "http://localhost:4566"
  }
}

# --- SECURITY (IAM) ---
# --- SEGURIDAD (IAM) ---

resource "aws_iam_role" "lambda_role" {
  name = "rotation_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# --- DATABASE INFRASTRUCTURE ---
# --- INFRAESTRUCTURA DE BASE DE DATOS ---

resource "aws_rds_cluster" "local_rds_cluster" {
  cluster_identifier  = "tf-localstack-rds"
  engine              = "aurora-postgresql"
  database_name       = "cloudflax"
  master_username     = "postgres"
  master_password     = "password"
  skip_final_snapshot = true
}

resource "aws_rds_cluster_instance" "local_rds_instance" {
  identifier         = "tf-localstack-rds-instance"
  cluster_identifier = aws_rds_cluster.local_rds_cluster.id
  instance_class     = "db.t3.micro"
  engine             = aws_rds_cluster.local_rds_cluster.engine
}

# --- SECRETS MANAGEMENT ---
# --- GESTIÓN DE SECRETOS ---

resource "aws_secretsmanager_secret" "db_secret" {
  name = "tf-localstack-db-secret" 
}

resource "aws_secretsmanager_secret_version" "db_secret_version" {
  secret_id     = aws_secretsmanager_secret.db_secret.id
  secret_string = jsonencode({
    username = aws_rds_cluster.local_rds_cluster.master_username
    password = aws_rds_cluster.local_rds_cluster.master_password
    host     = "host.docker.internal"
    port     = 4510
    dbname   = aws_rds_cluster.local_rds_cluster.database_name
  })
}

# --- ROTATION LAMBDA ---
# --- LAMBDA DE ROTACIÓN ---

resource "aws_lambda_function" "rotation_lambda" {
  filename      = "lambda/rotation_code.zip" 
  function_name = "tf-localstack-rotation-lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "rotation.handler" 
  runtime       = "python3.9"

  # Hash sync to detect code changes
  # Sincronización de hash para detectar cambios en el código
  source_code_hash = filebase64sha256("lambda/rotation_code.zip") 

  environment {
    variables = {
      # Internal endpoint for Lambda to see Secrets Manager
      # Endpoint interno para que la Lambda vea a Secrets Manager 
      SECRETS_MANAGER_ENDPOINT = "http://host.docker.internal:4566"
    }
  }
}

# --- ROTATION CONFIGURATION ---
# --- CONFIGURACIÓN DE ROTACIÓN ---

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