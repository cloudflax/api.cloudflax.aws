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
  secret_id           = var.db_secret_arn
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
  timeout          = 30
  source_code_hash = data.archive_file.cleanup_lambda_zip.output_base64sha256

  environment {
    variables = {
      AWS_REGION_NAME = var.aws_region
      DB_SECRET_ARN   = var.db_secret_arn
    }
  }
}

resource "aws_cloudwatch_event_rule" "cleanup_schedule" {
  name                = "cloudflax-${var.environment}-cleanup-schedule"
  schedule_expression = "rate(6 hours)"
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
