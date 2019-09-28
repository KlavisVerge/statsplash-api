terraform {
  backend "local" {
    path = "tf_backend/statsplash-api.tfstate"
  }
}

variable "AWS_ACCESS_KEY" {}
variable "AWS_SECRET_ACCESS_KEY" {}
variable "FORTNITE_TRN_API_KEY" {}
variable "PUBG_API_KEY" {}
variable "API_KEY" {}
variable "CLIENT_ID" {}

data "aws_iam_role" "role" {
  name = "apis-for-all-service-account"
}

provider "aws" {
  region     = "us-east-1"
  access_key = "${var.AWS_ACCESS_KEY}"
  secret_key = "${var.AWS_SECRET_ACCESS_KEY}"
}

resource "aws_api_gateway_rest_api" "api" {
  name               = "StatSplash API"
  description        = "StatSplash API"
  binary_media_types = ["multipart/form-data"]
}

resource "aws_api_gateway_resource" "health" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "health"
}

resource "aws_api_gateway_method" "health" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.health.id}"
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "health" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.health.id}"
  http_method = "GET"
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "health" {
  depends_on  = ["aws_api_gateway_method.health"]
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.health.id}"
  http_method = "${aws_api_gateway_method.health.http_method}"
  type        = "MOCK"

  request_templates = {
    "application/json" = "{ \"statusCode\": 200 }"
  }
}

resource "aws_api_gateway_integration_response" "health" {
  depends_on = [
    "aws_api_gateway_integration.health",
    "aws_api_gateway_method_response.health",
  ]

  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.health.id}"
  http_method = "${aws_api_gateway_method.health.http_method}"
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS,GET,PUT,PATCH,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# contact us start
resource "aws_dynamodb_table" "contact-us" {
  name           = "contact-us"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "email"
  range_key      = "rangekey"

  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "rangekey"
    type = "S"
  }

  lifecycle {
    ignore_changes = ["read_capacity", "write_capacity"]
  }
}

data "aws_caller_identity" "current" {}

resource "aws_appautoscaling_target" "dynamodb_table_read_target" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "table/${aws_dynamodb_table.contact-us.name}"
  role_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/dynamodb.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_DynamoDBTable"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_table_read_policy" {
  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.dynamodb_table_read_target.resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = "${aws_appautoscaling_target.dynamodb_table_read_target.resource_id}"
  scalable_dimension = "${aws_appautoscaling_target.dynamodb_table_read_target.scalable_dimension}"
  service_namespace  = "${aws_appautoscaling_target.dynamodb_table_read_target.service_namespace}"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }

    target_value = 80
  }
}

resource "aws_appautoscaling_target" "dynamodb_table_write_target" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "table/${aws_dynamodb_table.contact-us.name}"
  role_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/dynamodb.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_DynamoDBTable"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_table_write_policy" {
  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.dynamodb_table_write_target.resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = "${aws_appautoscaling_target.dynamodb_table_write_target.resource_id}"
  scalable_dimension = "${aws_appautoscaling_target.dynamodb_table_write_target.scalable_dimension}"
  service_namespace  = "${aws_appautoscaling_target.dynamodb_table_write_target.service_namespace}"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    target_value = 80
  }
}

resource "aws_api_gateway_resource" "contact-us-api-resource" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "contact-us-api"
}

resource "aws_lambda_function" "contact-us-api-function" {
  filename      = "statsplash-api.zip"
  function_name = "contact-us-api"

  role             = "${data.aws_iam_role.role.arn}"
  handler          = "src/contact-us-api.handler"
  source_code_hash = "${filebase64sha256("statsplash-api.zip")}"
  runtime          = "nodejs8.10"
  timeout          = 20
}

resource "aws_lambda_permission" "contact-us-permission" {
  function_name = "${aws_lambda_function.contact-us-api-function.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_method" "contact-us-api-method-post" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.contact-us-api-resource.id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "contact-us-api-integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.contact-us-api-resource.id}"
  http_method             = "POST"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.contact-us-api-function.invoke_arn}"
}

module "CORS_FUNCTION_DETAILS" {
  source      = "github.com/carrot/terraform-api-gateway-cors-module"
  resource_id = "${aws_api_gateway_resource.contact-us-api-resource.id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

#contact us end
#fortnite start
resource "aws_api_gateway_resource" "fortnite-api-resource" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "fortnite-api"
}

resource "aws_lambda_function" "fortnite-api-function" {
  filename      = "statsplash-api.zip"
  function_name = "fortnite-api"

  role             = "${data.aws_iam_role.role.arn}"
  handler          = "src/fortnite-api.handler"
  source_code_hash = "${filebase64sha256("statsplash-api.zip")}"
  runtime          = "nodejs8.10"
  timeout          = 20

  environment {
    variables = {
      FORTNITE_TRN_API_KEY = "${var.FORTNITE_TRN_API_KEY}"
    }
  }
}

resource "aws_lambda_permission" "fortnite-permission" {
  function_name = "${aws_lambda_function.fortnite-api-function.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_method" "fortnite-api-method-get" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.fortnite-api-resource.id}"
  http_method   = "GET"
  authorization = "NONE"

  request_validator_id = "${aws_api_gateway_request_validator.fortnite.id}"

  request_parameters = {
    "method.request.querystring.platform"     = true
    "method.request.querystring.epicNickname" = true
  }
}

resource "aws_api_gateway_request_validator" "fortnite" {
  name                        = "fortnite_validator"
  rest_api_id                 = "${aws_api_gateway_rest_api.api.id}"
  validate_request_parameters = true
}

resource "aws_api_gateway_method_response" "two-hundred-fortnite" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.fortnite-api-resource.id}"
  http_method = "GET"
  status_code = "200"
}

resource "aws_api_gateway_integration" "fortnite-api-integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.fortnite-api-resource.id}"
  http_method             = "GET"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.fortnite-api-function.invoke_arn}"
}

module "CORS_FORTNITE" {
  source      = "github.com/carrot/terraform-api-gateway-cors-module"
  resource_id = "${aws_api_gateway_resource.fortnite-api-resource.id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

#fortnite end
#league of legends start
resource "aws_api_gateway_resource" "league-of-legends-api-resource" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "league-of-legends-api"
}

resource "aws_lambda_function" "league-of-legends-api-function" {
  filename      = "statsplash-api.zip"
  function_name = "league-of-legends-api"

  role             = "${data.aws_iam_role.role.arn}"
  handler          = "src/league-of-legends-api.handler"
  source_code_hash = "${filebase64sha256("statsplash-api.zip")}"
  runtime          = "nodejs8.10"
  timeout          = 20

  environment {
    variables = {
      API_KEY = "${var.API_KEY}"
    }
  }
}

resource "aws_lambda_permission" "league-of-legends-permission" {
  function_name = "${aws_lambda_function.league-of-legends-api-function.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_method" "league-of-legends-api-method-get" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.league-of-legends-api-resource.id}"
  http_method   = "GET"
  authorization = "NONE"

  request_validator_id = "${aws_api_gateway_request_validator.league-of-legends.id}"

  request_parameters = {
    "method.request.querystring.summonerName" = true
    "method.request.querystring.region"       = true
  }
}

resource "aws_api_gateway_request_validator" "league-of-legends" {
  name                        = "league_of_legends_validator"
  rest_api_id                 = "${aws_api_gateway_rest_api.api.id}"
  validate_request_parameters = true
}

resource "aws_api_gateway_method_response" "two-hundred-league-of-legends" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  resource_id = "${aws_api_gateway_resource.league-of-legends-api-resource.id}"
  http_method = "GET"
  status_code = "200"
}

resource "aws_api_gateway_integration" "league-of-legends-api-integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.league-of-legends-api-resource.id}"
  http_method             = "GET"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.league-of-legends-api-function.invoke_arn}"
}

module "CORS_LEAGUE_OF_LEGENDS" {
  source      = "github.com/carrot/terraform-api-gateway-cors-module"
  resource_id = "${aws_api_gateway_resource.league-of-legends-api-resource.id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

#league of legends end
#league of legends match start
resource "aws_api_gateway_resource" "league-of-legends-match-api-resource" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "league-of-legends-match-api"
}

resource "aws_lambda_function" "league-of-legends-match-api-function" {
  filename      = "statsplash-api.zip"
  function_name = "league-of-legends-match-api"

  role             = "${data.aws_iam_role.role.arn}"
  handler          = "src/league-of-legends-match-api.handler"
  source_code_hash = "${filebase64sha256("statsplash-api.zip")}"
  runtime          = "nodejs8.10"
  timeout          = 20

  environment {
    variables = {
      API_KEY = "${var.API_KEY}"
    }
  }
}

resource "aws_lambda_permission" "league-of-legends-match-permission" {
  function_name = "${aws_lambda_function.league-of-legends-match-api-function.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_method" "league-of-legends-match-api-method-get" {
  rest_api_id          = "${aws_api_gateway_rest_api.api.id}"
  resource_id          = "${aws_api_gateway_resource.league-of-legends-match-api-resource.id}"
  http_method          = "GET"
  authorization        = "NONE"
  request_validator_id = "${aws_api_gateway_request_validator.league-of-legends-match.id}"

  request_parameters = {
    "method.request.querystring.region" = true
    "method.request.querystring.gameId" = true
  }
}

resource "aws_api_gateway_request_validator" "league-of-legends-match" {
  name                        = "league_of_legends_match_validator"
  rest_api_id                 = "${aws_api_gateway_rest_api.api.id}"
  validate_request_parameters = true
}

resource "aws_api_gateway_integration" "league-of-legends-match-api-integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.league-of-legends-match-api-resource.id}"
  http_method             = "GET"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.league-of-legends-match-api-function.invoke_arn}"
}

module "CORS_LEAGUE_OF_LEGENDS_MATCH" {
  source      = "github.com/carrot/terraform-api-gateway-cors-module"
  resource_id = "${aws_api_gateway_resource.league-of-legends-match-api-resource.id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

#league of legends match end
#reddit start
resource "aws_api_gateway_resource" "reddit-api-resource" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "reddit-api"
}

resource "aws_lambda_function" "reddit-api-function" {
  filename      = "statsplash-api.zip"
  function_name = "reddit-api"

  role             = "${data.aws_iam_role.role.arn}"
  handler          = "src/reddit-api.handler"
  source_code_hash = "${filebase64sha256("statsplash-api.zip")}"
  runtime          = "nodejs8.10"
  timeout          = 20
}

resource "aws_lambda_permission" "reddit-permission" {
  function_name = "${aws_lambda_function.reddit-api-function.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_method" "reddit-api-method-get" {
  rest_api_id          = "${aws_api_gateway_rest_api.api.id}"
  resource_id          = "${aws_api_gateway_resource.reddit-api-resource.id}"
  http_method          = "GET"
  authorization        = "NONE"
  request_validator_id = "${aws_api_gateway_request_validator.reddit.id}"

  request_parameters = {
    "method.request.querystring.game" = true
  }
}

resource "aws_api_gateway_request_validator" "reddit" {
  name                        = "reddit_validator"
  rest_api_id                 = "${aws_api_gateway_rest_api.api.id}"
  validate_request_parameters = true
}

resource "aws_api_gateway_integration" "reddit-api-integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.reddit-api-resource.id}"
  http_method             = "GET"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.reddit-api-function.invoke_arn}"
}

module "CORS_REDDIT" {
  source      = "github.com/carrot/terraform-api-gateway-cors-module"
  resource_id = "${aws_api_gateway_resource.reddit-api-resource.id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

#reddit end
#submit an idea start
resource "aws_dynamodb_table" "submit-an-idea" {
  name           = "submit-an-idea"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "email"
  range_key      = "rangekey"

  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "rangekey"
    type = "S"
  }

  lifecycle {
    ignore_changes = ["read_capacity", "write_capacity"]
  }
}

resource "aws_appautoscaling_target" "dynamodb_table_read_target_submit" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "table/${aws_dynamodb_table.submit-an-idea.name}"
  role_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/dynamodb.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_DynamoDBTable"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_table_read_policy_submit" {
  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.dynamodb_table_read_target_submit.resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = "${aws_appautoscaling_target.dynamodb_table_read_target_submit.resource_id}"
  scalable_dimension = "${aws_appautoscaling_target.dynamodb_table_read_target_submit.scalable_dimension}"
  service_namespace  = "${aws_appautoscaling_target.dynamodb_table_read_target_submit.service_namespace}"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }

    target_value = 80
  }
}

resource "aws_appautoscaling_target" "dynamodb_table_write_target_submit" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "table/${aws_dynamodb_table.submit-an-idea.name}"
  role_arn           = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/dynamodb.application-autoscaling.amazonaws.com/AWSServiceRoleForApplicationAutoScaling_DynamoDBTable"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_table_write_policy_submit" {
  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.dynamodb_table_write_target_submit.resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = "${aws_appautoscaling_target.dynamodb_table_write_target_submit.resource_id}"
  scalable_dimension = "${aws_appautoscaling_target.dynamodb_table_write_target_submit.scalable_dimension}"
  service_namespace  = "${aws_appautoscaling_target.dynamodb_table_write_target_submit.service_namespace}"

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }

    target_value = 80
  }
}

resource "aws_api_gateway_resource" "submit-an-idea-api-resource" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "submit-an-idea-api"
}

resource "aws_lambda_function" "submit-an-idea-api-function" {
  filename      = "statsplash-api.zip"
  function_name = "submit-an-idea-api"

  role             = "${data.aws_iam_role.role.arn}"
  handler          = "src/submit-an-idea-api.handler"
  source_code_hash = "${filebase64sha256("statsplash-api.zip")}"
  runtime          = "nodejs8.10"
  timeout          = 20
}

resource "aws_lambda_permission" "submit-an-idea-permission" {
  function_name = "${aws_lambda_function.submit-an-idea-api-function.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_method" "submit-an-idea-api-method-post" {
  rest_api_id   = "${aws_api_gateway_rest_api.api.id}"
  resource_id   = "${aws_api_gateway_resource.submit-an-idea-api-resource.id}"
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "submit-an-idea-api-integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.submit-an-idea-api-resource.id}"
  http_method             = "POST"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.submit-an-idea-api-function.invoke_arn}"
}

module "CORS_SUBMIT_AN_API" {
  source      = "github.com/carrot/terraform-api-gateway-cors-module"
  resource_id = "${aws_api_gateway_resource.submit-an-idea-api-resource.id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

#submit an idea end
#twitch start
resource "aws_api_gateway_resource" "twitch-api-resource" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "twitch-api"
}

resource "aws_api_gateway_resource" "twitch-games-resource" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "twitch-games"
}

resource "aws_lambda_function" "twitch-api-function" {
  filename      = "statsplash-api.zip"
  function_name = "twitch-api"

  role             = "${data.aws_iam_role.role.arn}"
  handler          = "src/twitch-api.handler"
  source_code_hash = "${filebase64sha256("statsplash-api.zip")}"
  runtime          = "nodejs8.10"
  timeout          = 20

  environment {
    variables = {
      CLIENT_ID = "${var.CLIENT_ID}"
    }
  }
}

resource "aws_lambda_function" "twitch-games-function" {
  filename      = "statsplash-api.zip"
  function_name = "twitch-games"

  role             = "${data.aws_iam_role.role.arn}"
  handler          = "src/twitch-games.handler"
  source_code_hash = "${filebase64sha256("statsplash-api.zip")}"
  runtime          = "nodejs8.10"
  timeout          = 20

  environment {
    variables = {
      CLIENT_ID = "${var.CLIENT_ID}"
    }
  }
}

resource "aws_lambda_permission" "twitch-permission" {
  function_name = "${aws_lambda_function.twitch-api-function.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_lambda_permission" "twitch-permission-games" {
  function_name = "${aws_lambda_function.twitch-games-function.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_method" "twitch-api-method-get" {
  rest_api_id          = "${aws_api_gateway_rest_api.api.id}"
  resource_id          = "${aws_api_gateway_resource.twitch-api-resource.id}"
  http_method          = "GET"
  authorization        = "NONE"
  request_validator_id = "${aws_api_gateway_request_validator.twitch.id}"

  request_parameters = {
    "method.request.querystring.gameName" = true
  }
}

resource "aws_api_gateway_request_validator" "twitch" {
  name                        = "twitch_validator"
  rest_api_id                 = "${aws_api_gateway_rest_api.api.id}"
  validate_request_parameters = true
}

resource "aws_api_gateway_method" "twitch-games-method-get" {
  rest_api_id          = "${aws_api_gateway_rest_api.api.id}"
  resource_id          = "${aws_api_gateway_resource.twitch-games-resource.id}"
  http_method          = "GET"
  authorization        = "NONE"
  request_validator_id = "${aws_api_gateway_request_validator.twitch-games.id}"

  request_parameters = {
    "method.request.querystring.games" = true
  }
}

resource "aws_api_gateway_request_validator" "twitch-games" {
  name                        = "twitch_games_validator"
  rest_api_id                 = "${aws_api_gateway_rest_api.api.id}"
  validate_request_parameters = true
}

resource "aws_api_gateway_integration" "twitch-api-integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.twitch-api-resource.id}"
  http_method             = "GET"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.twitch-api-function.invoke_arn}"
}

resource "aws_api_gateway_integration" "twitch-games-api-integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.twitch-games-resource.id}"
  http_method             = "GET"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.twitch-games-function.invoke_arn}"
}

module "CORS_TWITCH" {
  source      = "github.com/carrot/terraform-api-gateway-cors-module"
  resource_id = "${aws_api_gateway_resource.twitch-api-resource.id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

module "CORS_TWITCH_GAMES" {
  source      = "github.com/carrot/terraform-api-gateway-cors-module"
  resource_id = "${aws_api_gateway_resource.twitch-games-resource.id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

#twitch end

#PUGB start
resource "aws_api_gateway_resource" "pubg-api-resource" {
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
  parent_id   = "${aws_api_gateway_rest_api.api.root_resource_id}"
  path_part   = "pubg-api"
}

resource "aws_lambda_function" "pubg-api-function" {
  filename      = "statsplash-api.zip"
  function_name = "pubg-api"

  role             = "${data.aws_iam_role.role.arn}"
  handler          = "src/pubg-api.handler"
  source_code_hash = "${filebase64sha256("statsplash-api.zip")}"
  runtime          = "nodejs8.10"
  timeout          = 20

  environment {
    variables = {
      PUBG_API_KEY = "${var.PUBG_API_KEY}"
    }
  }
}

resource "aws_lambda_permission" "pubg-permission" {
  function_name = "${aws_lambda_function.pubg-api-function.function_name}"
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_method" "pubg-api-method-get" {
  rest_api_id          = "${aws_api_gateway_rest_api.api.id}"
  resource_id          = "${aws_api_gateway_resource.pubg-api-resource.id}"
  http_method          = "GET"
  authorization        = "NONE"
  request_validator_id = "${aws_api_gateway_request_validator.pubg.id}"

  request_parameters = {
    "method.request.querystring.region" = true,
    "method.request.querystring.playerName" = true
  }
}

resource "aws_api_gateway_request_validator" "pubg" {
  name                        = "pubg_validator"
  rest_api_id                 = "${aws_api_gateway_rest_api.api.id}"
  validate_request_parameters = true
}

resource "aws_api_gateway_integration" "pubg-api-integration" {
  rest_api_id             = "${aws_api_gateway_rest_api.api.id}"
  resource_id             = "${aws_api_gateway_resource.pubg-api-resource.id}"
  http_method             = "GET"
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.pubg-api-function.invoke_arn}"
}

module "CORS_PUBG" {
  source      = "github.com/carrot/terraform-api-gateway-cors-module"
  resource_id = "${aws_api_gateway_resource.pubg-api-resource.id}"
  rest_api_id = "${aws_api_gateway_rest_api.api.id}"
}

#PUBG end

resource "aws_api_gateway_deployment" "APIs" {
  depends_on = [
    "aws_api_gateway_integration_response.health",
    "aws_api_gateway_integration.contact-us-api-integration",
    "aws_api_gateway_integration.fortnite-api-integration",
    "aws_api_gateway_integration.league-of-legends-api-integration",
    "aws_api_gateway_integration.league-of-legends-match-api-integration",
    "aws_api_gateway_integration.reddit-api-integration",
    "aws_api_gateway_integration.submit-an-idea-api-integration",
    "aws_api_gateway_integration.twitch-api-integration",
    "aws_api_gateway_integration.twitch-games-api-integration",
    "aws_api_gateway_integration.pubg-api-integration",
  ]

  rest_api_id       = "${aws_api_gateway_rest_api.api.id}"
  stage_name        = "api"
  stage_description = "${timestamp()}"
  description       = "Deployed ${timestamp()}"
}
