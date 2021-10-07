resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "java-project-code-build-project-artifacts"
  acl    = "private"
}

data "aws_subnet_ids" "dev_subnet" {
  vpc_id = var.vpc_id
  filter {
    name   = "tag:Name"
    values = ["*Private*"]
  }
}

resource "aws_iam_instance_profile" "application_instance_profile" {
  name = "${var.java_app_name}-InstanceProfile"
  role = aws_iam_role.application_instance_role.id
}

resource "aws_iam_role" "application_instance_role" {
  name = "${var.java_app_name}-InstanceRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "s3_access" {
  name = "${var.java_app_name}-SS3InstanceRolePolicy"
  role = aws_iam_role.application_instance_role.id
  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "s3:*"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy" "ssm_access" {
  name = "${var.java_app_name}-SSMInstanceRolePolicy"
  role = aws_iam_role.application_instance_role.id
  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeAssociation",
                "ssm:GetDeployablePatchSnapshotForInstance",
                "ssm:GetDocument",
                "ssm:DescribeDocument",
                "ssm:GetManifest",
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:ListAssociations",
                "ssm:ListInstanceAssociations",
                "ssm:PutInventory",
                "ssm:PutComplianceItems",
                "ssm:PutConfigurePackageResult",
                "ssm:UpdateAssociationStatus",
                "ssm:UpdateInstanceAssociationStatus",
                "ssm:UpdateInstanceInformation",
                "ssm:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2messages:AcknowledgeMessage",
                "ec2messages:DeleteMessage",
                "ec2messages:FailMessage",
                "ec2messages:GetEndpoint",
                "ec2messages:GetMessages",
                "ec2messages:SendReply",
                "ec2:*"
            ],
            "Resource": "*"
        }
    ]
  }
  EOF
}