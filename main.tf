# include terraform-glue-data-crawler module which will call terraform-aws-athena-view module 
module "terraform-glue-data-crawler" {
    source = "./modules/terraform-glue-data-crawler"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
    shared_credentials_file = "~/.aws/credentials"
    region  = var.aws_region
}

provider "archive" {}
data "archive_file" "lambda_zip" {
    type        = "zip"
    source_file = "lambda_function.py"
    output_path = "lambda_function.zip"
}

data "aws_canonical_user_id" "current" {}

# create s3 bucket for merakisecurityreport.jsonl file to be put by lambda 
resource "aws_s3_bucket" "merakisecurityreport" {
    bucket = "meraki-security-report"

    tags = {
        Name = "meraki-security-report"
        Environment = "Dev"
    }
}

resource "aws_s3_bucket_acl" "merakisecurityreportacl" {
     bucket = aws_s3_bucket.merakisecurityreport.id
     access_control_policy {
        grant {
            grantee {
                id = data.aws_canonical_user_id.current.id
                type = "CanonicalUser"
            }
            permission = "FULL_CONTROL"
        }

        grant {
            grantee {
                type = "Group"
                uri = "http://acs.amazonaws.com/groups/s3/LogDelivery"
            }
            permission = "READ_ACP"
        }

        owner {
            id = data.aws_canonical_user_id.current.id
        }
     }
 }

# create s3 bucket for archived merakisecurityreport.jsonl file with unique date to be put by lambda 
resource "aws_s3_bucket" "merakisecurityreportsarchive" {
    bucket = "meraki-security-reports-archive"

    tags = {
        Name = "meraki-security-reports-archive"
        Environment = "Dev" 
    }
}

resource "aws_s3_bucket_acl" "merakisecurityreportsarchiveacl" {
    bucket = aws_s3_bucket.merakisecurityreportsarchive.id
    access_control_policy {
        grant {
            grantee {
                id = data.aws_canonical_user_id.current.id
                type = "CanonicalUser"
            }
            permission = "FULL_CONTROL"
        }

        grant {
            grantee {
                type = "Group"
                uri = "http://acs.amazonaws.com/groups/s3/LogDelivery"
            }
            permission = "READ_ACP"
        }

        owner {
            id = data.aws_canonical_user_id.current.id
        }
     }
 }


# create iam role for lambda function creation
resource "aws_iam_role" "merakisecurityreport_lambda" {
    name = "meraki_security_report_lambda_role"
    path = "/"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Sid = ""
                Principal = {
                    Service = "lambda.amazonaws.com"
                }
            }, 
        ]
    })
}

# create iam policy to attach to meraki_security_report_lambda role 
resource "aws_iam_policy" "merakisecurityreport_lambda" {
    name = "meraki_security_report_iam_policy"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                "Effect": "Allow", 
                "Action": [
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                ],
                "Resource": "arn:aws:logs:*:*:*"
            }, 
            {
                "Effect": "Allow", 
                "Action": [
                    "s3:PutObject", 
                    "logs:CreateLogGroup"
                ], 
                "Resource": "arn:aws:s3:::*"
            }
        ]
    })
}

# attach merakisecurityreport_lambda iam role to merakisecurityreport_lambda iam policy 
resource "aws_iam_role_policy_attachment" "attach" {
    role = "${aws_iam_role.merakisecurityreport_lambda.name}" 
    policy_arn = "${aws_iam_policy.merakisecurityreport_lambda.arn}"
}

# create lambda layer to include jsonlines library 
resource "aws_lambda_layer_version" "lambda_layer" {
    filename = "jsonlines-library.zip"
    layer_name = "jsonlines-library" 

    compatible_runtimes = ["python3.9"]

    skip_destroy = true 
}

# create merakisecurityreport lambda function that uses merakisecurityreport_lambda iam role, lambda_function.zip, and lambda layer
resource "aws_lambda_function" "merakisecurityreport" {
    function_name = "merakisecurityreport_lambda"
    filename = data.archive_file.lambda_zip.output_path
    source_code_hash = data.archive_file.lambda_zip.output_base64sha256
    role = "${aws_iam_role.role.arn}"
    handler = "lambda_function.lambda_handler"
    runtime = "python3.9"
    timeout = 180

    layers = [
        aws_lambda_layer_version.lambda_layer.arn
    ]

    environment {
        variables = {
            meraki_api_key = var.meraki_api_key
            network_id = var.network_id
        }
    }

    provisioner "local-exec" {
    command = "aws lambda invoke --function-name merakisecurityreport_lambda out" 
  }
}

# create cloudwatch event that will trigger merakisecurityreport lambda to run every week on Monday at 1am 
resource "aws_cloudwatch_event_rule" "merakisecurityreport_lambda" {
    name = "merakisecurityreport_lambda_event_rule"
    description = "run every week on Monday at 1am"
    schedule_expression = "cron(0 1 ? 1-12 mon *)"
}

# attach cloudwatch event to merakisecurityreport lambda function 
resource "aws_cloudwatch_event_target" "merakisecurityreport_lambda" {
    arn = aws_lambda_function.merakisecurityreport.arn
    rule = aws_cloudwatch_event_rule.merakisecurityreport_lambda.name
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
    statement_id = "AllowExecutionFromCloudWatch"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.merakisecurityreport.function_name
    principal = "events.amazonaws.com"
    source_arn = aws_cloudwatch_event_rule.merakisecurityreport_lambda.arn
}