provider "aws" {
  profile = "default"
  region  = "ap-south-1"
}
resource "aws_dynamodb_table" "product_table" {
  name         = "PRODUCT"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "product_id"
  attribute {
    name = "product_id"
    type = "S"
  }
  attribute {
    name = "category"
    type = "S"
  }
  attribute {
    name = "product_rating"
    type = "N"
  }
  global_secondary_index {
    name            = "ProductCategoryRatingIndex"
    hash_key        = "category"
    range_key       = "product_rating"
    projection_type = "ALL"
  }
}

resource "aws_api_gateway_rest_api" "product_apigw" {
  name        = "product_apigw"
  description = "Product API Gateway"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}
resource "aws_api_gateway_resource" "product" {
  rest_api_id = aws_api_gateway_rest_api.product_apigw.id
  parent_id   = aws_api_gateway_rest_api.product_apigw.root_resource_id
  path_part   = "product"
}
resource "aws_api_gateway_method" "createproduct" {
  rest_api_id   = aws_api_gateway_rest_api.product_apigw.id
  resource_id   = aws_api_gateway_resource.product.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_iam_role" "ProductLambdaRole" {
  name               = "ProductLambdaRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
data "template_file" "productlambdapolicy" {
  template = "${file("${path.module}/policy.json")}"
}
resource "aws_iam_policy" "ProductLambdaPolicy" {
  name        = "ProductLambdaPolicy"
  path        = "/"
  description = "IAM policy for Product lambda functions"
  policy      = data.template_file.productlambdapolicy.rendered
}
resource "aws_iam_role_policy_attachment" "ProductLambdaRolePolicy" {
  role       = aws_iam_role.ProductLambdaRole.name
  policy_arn = aws_iam_policy.ProductLambdaPolicy.arn
}

resource "aws_lambda_function" "CreateProductHandler" {
  function_name = "CreateProductHandler"
  filename = "../lambda/product_lambda.zip"
  handler = "createproduct.lambda_handler"
  runtime = "python3.8"
  environment {
    variables = {
      REGION        = "ap-south-1"
      PRODUCT_TABLE = aws_dynamodb_table.product_table.name
   }
  }
  source_code_hash = filebase64sha256("../lambda/product_lambda.zip")
  role = aws_iam_role.ProductLambdaRole.arn
  timeout     = "5"
  memory_size = "128"
}

resource "aws_api_gateway_integration" "createproduct-lambda" {
rest_api_id = aws_api_gateway_rest_api.product_apigw.id
  resource_id = aws_api_gateway_method.createproduct.resource_id
  http_method = aws_api_gateway_method.createproduct.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
uri = aws_lambda_function.CreateProductHandler.invoke_arn
}
resource "aws_lambda_permission" "apigw-CreateProductHandler" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.CreateProductHandler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${aws_api_gateway_rest_api.product_apigw.execution_arn}/*/POST/product"
}
resource "aws_api_gateway_deployment" "productapistageprod" {
  depends_on = [
    aws_api_gateway_integration.createproduct-lambda
  ]
  rest_api_id = aws_api_gateway_rest_api.product_apigw.id
  stage_name  = "prod"
}