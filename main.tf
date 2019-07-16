terraform {
  required_version = ">= 0.12.4"
  backend "s3" {}
}

provider "aws" {
  region = var.region
}

data "terraform_remote_state" "state" {
  backend = "s3"
  config = {
    bucket  = var.terraform_state["bucket"]
    region  = var.region
    key     = var.terraform_state["key"]
    encrypt = true
  }
}

data "aws_caller_identity" "current_account_id" {}

module "lambda_label" {
  source     = "git::https://github.com/cloudposse/terraform-terraform-label.git"
  namespace  = var.namespace
  stage      = var.stage
  name       = var.name
  attributes = ["lambda", var.region]
  delimiter  = var.delimiter
  tags       = var.tags
}

////////////////////// LAMBDA IAM:

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    sid     = "HelloWorldLambdaTrustPolicy"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid    = "HelloWorldLambdaPolicy"
    effect = "Allow"
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
    ]
    resources = ["arn:aws:logs:${var.region}:${data.aws_caller_identity.current_account_id.account_id}:*"]
  }
}

resource "aws_iam_role" "lambda" {
  name               = module.lambda_label.id
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_policy" "lambda" {
  name   = module.lambda_label.id
  policy = data.aws_iam_policy_document.lambda.json
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}

////////////////////// LAMBDA FUNCTION:

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/"
  output_path = "${path.module}/lambda/hello_world.zip"
}

resource "aws_lambda_function" "lambda" {
  description      = "Hello World Lambda function"
  filename         = join("", data.archive_file.lambda.*.output_path)
  function_name    = "hello_world"
  role             = aws_iam_role.lambda.arn
  handler          = "hello_world.lambda_handler"
  source_code_hash = join("", data.archive_file.lambda.*.output_base64sha256)
  runtime          = "python3.6"
}
