provider "aws" {
  region  = "${var.region}"
}

data "terraform_remote_state" "splunk_firehose" {
  backend = "s3"
  config {
    bucket  = "${lookup(var.terraform_state, "bucket")}"
    region  = "${var.region}"
    key     = "${lookup(var.terraform_state, "key")}"
    encrypt = true
  }
}

terraform {
  backend "s3" {}
}

data "aws_caller_identity" "current_account_id" {}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/"
  output_path = "${path.module}/lambda/hello_world.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    sid    = "HelloWorldLambdaTrustPolicy"
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com",
      ]
    }
  }
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid = "HelloWorldLambdaPolicy"
    effect = "Allow"
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
    ]
    resources = [
      "arn:aws:logs:${var.region}:${data.aws_caller_identity.current_account_id.account_id}:*",    ]
  }
}

resource "aws_lambda_function" "lambda" {
  description      = "Hello World Lambda function"
  filename         = "${join("", data.archive_file.lambda.*.output_path)}"
  function_name    = "hello_world"
  role             = "${aws_iam_role.lambda.arn}"
  handler          = "hello_world.lambda_handler"
  source_code_hash = "${join("", data.archive_file.lambda.*.output_base64sha256)}"
  runtime          = "python3.6"
}

resource "aws_iam_role" "lambda" {
  name               = "hello_world_lambda"
  assume_role_policy = "${data.aws_iam_policy_document.lambda_assume_role.json}"
}

resource "aws_iam_policy" "lambda" {
  name   = "hello_world_policy"
  policy = "${data.aws_iam_policy_document.lambda.json}"
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = "${aws_iam_role.lambda.name}"
  policy_arn = "${aws_iam_policy.lambda.arn}"
}
