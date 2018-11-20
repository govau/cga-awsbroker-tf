# IAM policies etc from:
# https://github.com/awslabs/aws-servicebroker/blob/master/docs/install_prereqs.md

variable "name" {} // Platform name ("a", "z", or whatever)

variable "region" {
  default = "ap-southeast-2"
}

variable "bosh_jumpbox_role_id" {}

variable "cld_internal_zone_id" {
  description = "AWS zone ID for cld.internal"
}

resource "aws_route53_record" "broker_db_txt" {
  zone_id = "${var.cld_internal_zone_id}"
  name    = "awsbroker.cld.internal."
  type    = "TXT"
  ttl     = 300

  records = [
    "enabled=1",
    "tablename=${aws_dynamodb_table.awsbroker_table.name}",
    "iamusername=${aws_iam_user.awsbroker.name}",
  ]
}

resource "aws_dynamodb_table" "awsbroker_table" {
  name           = "awssb"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "id"
  range_key      = "userid"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "userid"
    type = "S"
  }

  attribute {
    name = "type"
    type = "S"
  }

  global_secondary_index {
    name            = "type-userid-index"
    hash_key        = "type"
    range_key       = "userid"
    write_capacity  = 5
    read_capacity   = 5
    projection_type = "INCLUDE"

    non_key_attributes = [
      "id",
      "userid",
      "type",
      "locked",
    ]
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "bosh_jumpbox" {
  role   = "${var.bosh_jumpbox_role_id}"
  policy = "${data.aws_iam_policy_document.create_awsbroker_access.json}"
}

data "aws_iam_policy_document" "create_awsbroker_access" {
  statement {
    actions   = ["iam:CreateAccessKey"]
    resources = ["${aws_iam_user.awsbroker.arn}"]
  }
}

resource "aws_iam_user" "awsbroker" {
  name          = "${var.name}-cld-awsbroker"
  force_destroy = true
}

resource "aws_iam_user_policy" "awsbroker_run_as_broker" {
  user   = "${aws_iam_user.awsbroker.name}"
  policy = "${data.aws_iam_policy_document.run_as_broker.json}"
}

data "aws_iam_policy_document" "run_as_broker" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::awsservicebroker/templates/*",
      "arn:aws:s3:::awsservicebroker",
    ]
  }

  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:DeleteItem",
    ]

    resources = [
      "${aws_dynamodb_table.awsbroker_table.arn}",
    ]
  }

  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
    ]

    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/asb-*",
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/Asb*",
    ]
  }
}

resource "aws_iam_user_policy" "awsbroker_manage_service_instances" {
  user   = "${aws_iam_user.awsbroker.name}"
  policy = "${data.aws_iam_policy_document.manage_service_instances.json}"
}

data "aws_iam_policy_document" "manage_service_instances" {
  statement {
    actions = [
      "ssm:PutParameter",
    ]

    resources = [
      "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/asb-*",
    ]
  }

  statement {
    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::awsservicebroker/templates/*",
    ]
  }

  statement {
    actions = [
      "cloudformation:CreateStack",
      "cloudformation:DeleteStack",
      "cloudformation:DescribeStacks",
      "cloudformation:UpdateStack",
      "cloudformation:CancelUpdateStack",
    ]

    resources = [
      "arn:aws:cloudformation:${var.region}:${data.aws_caller_identity.current.account_id}:stack/aws-service-broker-*/*",
    ]
  }

  statement {
    actions = [
      "athena:*",
      "dynamodb:*",
      "kms:*",
      "elasticache:*",
      "elasticmapreduce:*",
      "kinesis:*",
      "rds:*",
      "redshift:*",
      "route53:*",
      "s3:*",
      "sns:*",
      "sqs:*",
      "ec2:*",
      "iam:*",
      "lambda:*",
    ]

    resources = [
      "*",
    ]
  }
}
