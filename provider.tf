provider "aws" {
  region = "ap-southeast-1"  # Choose your preferred region
}

# Create IAM Role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach policy to allow Lambda to log to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create the Lambda function
resource "aws_lambda_function" "api_mock" {
  function_name    = "jsonplaceholder_users"
  runtime          = "python3.8" # or python3.9 if you prefer
  handler          = "lambda_function.lambda_handler"
  role             = aws_iam_role.lambda_exec_role.arn
  filename         = "lambda_function_payload.zip"  # Path to your zipped function
  source_code_hash = filebase64sha256("lambda_function_payload.zip")

  environment {
    variables = {
      ENV = "dev"
    }
  }
}

# Optionally, create an API Gateway to trigger the Lambda
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "lambda_api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.lambda_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.api_mock.arn
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "GET /users"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "lambda_stage" {
  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = "$default"
  auto_deploy = true
}

output "lambda_url" {
  value = aws_apigatewayv2_stage.lambda_stage.invoke_url
}
