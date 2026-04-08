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
        Resource = var.db_secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "cloudflax-${var.environment}-lambda-dynamodb-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          aws_dynamodb_table.api_throttle_locks.arn,
          "${aws_dynamodb_table.api_throttle_locks.arn}/index/*"
        ]
      }
    ]
  })
}

# ---------------- SEND VERIFY EMAIL LAMBDA (SES only) ----------------

resource "aws_iam_role" "send_verify_email_lambda_role" {
  name = "cloudflax-${var.environment}-send-verify-email-role"

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

resource "aws_iam_role_policy_attachment" "send_verify_email_basic_execution" {
  role       = aws_iam_role.send_verify_email_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "send_verify_email_ses" {
  name = "cloudflax-${var.environment}-send-verify-email-ses"
  role = aws_iam_role.send_verify_email_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SendTransactionalEmail"
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
        ]
        Resource = "*"
      }
    ]
  })
}

# ---------------- SEND FORGOT PASSWORD EMAIL LAMBDA (SES only) ----------------

resource "aws_iam_role" "send_forgot_password_email_lambda_role" {
  name = "cloudflax-${var.environment}-send-forgot-password-email-role"

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

resource "aws_iam_role_policy_attachment" "send_forgot_password_email_basic_execution" {
  role       = aws_iam_role.send_forgot_password_email_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "send_forgot_password_email_ses" {
  name = "cloudflax-${var.environment}-send-forgot-password-email-ses"
  role = aws_iam_role.send_forgot_password_email_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SendTransactionalEmail"
        Effect = "Allow"
        Action = [
          "ses:SendEmail",
        ]
        Resource = "*"
      }
    ]
  })
}
