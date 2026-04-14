# Zip the lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/api.py"
  output_path = "${path.module}/lambda/api.zip"
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda-api-role-${var.environment}"

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

# Attach basic Lambda execution policy (logs only)
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ✅ NEW: अनुमति to read Secrets Manager
resource "aws_iam_role_policy" "lambda_secrets" {
  name = "lambda-secrets-policy-${var.environment}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = "arn:aws:secretsmanager:*:*:secret:lamda-${var.environment}-api-key*"
    }]
  })
}

# Lambda function
resource "aws_lambda_function" "api" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "api-${var.environment}"
  role             = aws_iam_role.lambda_role.arn
  handler          = "api.handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # ✅ NEW: pass secret name to Lambda
  environment {
    variables = {
      SECRET_NAME = "lamda-${var.environment}-api-key"
    }
  }

  tags = {
    Name        = "api-${var.environment}"
    Environment = var.environment
  }
}

# API Gateway
resource "aws_apigatewayv2_api" "api" {
  name          = "api-${var.environment}"
  protocol_type = "HTTP"

  tags = {
    Name        = "api-${var.environment}"
    Environment = var.environment
  }
}

# Lambda integration
resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

# Health check route
resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Projects route
resource "aws_apigatewayv2_route" "projects" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /projects"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Stage
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Name        = "api-stage-${var.environment}"
    Environment = var.environment
  }
}

# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}