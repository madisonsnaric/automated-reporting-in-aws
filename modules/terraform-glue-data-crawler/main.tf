module "terraform-aws-athena-views" {
    source = "../terraform-aws-athena-views"
}

resource "aws_s3_bucket" "merakisecurityevents-query-results" {
    bucket = "merakisecurityevents-query-results"
}

resource "aws_iam_role" "role" {
    name = "awsglueservicerole_merakisecurityreport"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "glue.amazonaws.com"
                }
            }
        ]
    })
}

resource "aws_iam_policy" "glue_merakisecurityreport_policy" {
    name = "glue_merakisecurityreport_policy"
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListAccessPointsForObjectLambda",
                "athena:ListEngineVersions",
                "s3:GetAccessPoint",
                "athena:ListDataCatalogs",
                "s3:PutAccountPublicAccessBlock",
                "s3:ListAccessPoints",
                "s3:ListJobs",
                "s3:PutStorageLensConfiguration",
                "athena:ListWorkGroups",
                "s3:ListMultiRegionAccessPoints",
                "s3:ListStorageLensConfigurations",
                "s3:GetAccountPublicAccessBlock",
                "s3:ListAllMyBuckets",
                "s3:PutAccessPointPublicAccessBlock",
                "s3:CreateJob"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "athena:*"
            ],
            "Resource": [
                "arn:aws:s3:::meraki-security-report*",
                "arn:aws:athena:*:*:datacatalog/*",
                "arn:aws:athena:*:*:workgroup/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": "arn:aws:s3:::merakisecurityevents-query-results*"
        }
        ]
    })
}

# attach IAM role to IAM policy 
resource "aws_iam_role_policy_attachment" "attach_glue_merakisecurityreport_policy" {
    role = aws_iam_role.role.name
    policy_arn = aws_iam_policy.glue_merakisecurityreport_policy.arn 
}

resource "aws_iam_role_policy_attachment" "attach_awsglueservicerole" {
    role = aws_iam_role.role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_glue_catalog_database" "merakisecurityevent_database" {
    name = "merakisecurityevents"
}

# grant data lake permissions to glue catalog database 
resource "aws_lakeformation_permissions" "example1" {
    principal = aws_iam_role.role.arn
    permissions = ["ALL"]

    database {
        name = aws_glue_catalog_database.merakisecurityevent_database.name
    }
}

resource "aws_glue_crawler" "crawler" {
    database_name = aws_glue_catalog_database.merakisecurityevent_database.name 
    name = "merakisecurityevents"
    role = aws_iam_role.role.arn 
    table_prefix = "table_"

    s3_target {
        # path = "s3://meraki-security-report/merakisecurityreport.jsonl"
        path = "s3://meraki-security-report"
    }

    provisioner "local-exec" {
    command = "aws glue start-crawler --name ${self.name}"
  }
}