terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.5.0"
    }
    javascript = {
      source = "apparentlymart/javascript"
      version = "0.0.1"
    }
    
  }
}


#For testing porpuses only, working in this with a most secure way 

provider "aws" {
    region = "us-east-1"
    access_key = ""
    secret_key = ""
}

/* 1.	Create Lambda execution role
2.	Create and trigger Lambda functions to launch destination resources in other region
3.	Create destination CMK key and create Alias. . Allow only EC2 role to encypt and decrypt and admin role to maintain the key. 
4.	Create and trigger Lambda functions to create and configure destination bucket 
a.	Create destination bucket 
b.	Update bucket properties to enable bucket versioning
c.	 Update bucket properties to default encryption using aws:kms and created CMK
d.	Update bucket policy to deny upload objects which are not encrypted
e.	Update bucket lifecycle to move objects from standard s3 to glacier. Rotation period 7 days in stander s3 and one year in glacier before delete them from glacier. 
5.	Create source CMK key and create Alias in current region. Allow only EC2 role to encypt and decrypt and admin role to maintain the key. 
6.	Create s3 service role to allow s3 replication. Create custom policy to allow only replication objects which are encrypt using source CMK and encrypt them back using target CMK key. 
7.	Create and configure source bucket
a.	Update bucket properties to enable bucket versioning
b.	Update bucket properties to default encryption using aws:kms and created CMK
c.	Update bucket policy to deny upload objects which are not encrypted
d.	Update bucket properties to default encryption using aws:kms and created CMK
e.	Update bucket policy to deny upload objects which are not encrypted
f.	Update bucket lifecycle to move objects from standard s3 to glacier. Rotation period 7 days in stander s3 and one year in glacier before delete
8.	Enable bucket replication.  */


variable "RepRegion" {
  type        = string
  description = "Enter Region for offsite backup (Replication to other Region)"
/*   allowed_values = [
    "us-east-1",
    "us-east-2",
    "us-west-1",
    "us-west-2",
    "ca-central-1",
    "ap-south-1",
    "ap-northeast-2",
    "ap-southeast-1",
    "ap-southeast-2",
    "ap-northeast-1",
    "eu-central-1",
    "eu-west-1",
    "eu-west-2",
    "sa-east-1",
  ] */
}

variable "ReplicationBucketName" {
  type        = string
  description = "Enter Replication bucket name in selected region"
}

variable "OriginalBucketName" {
  type        = string
  description = "Enter Source bucket name for backup in current Region"
}

variable "ReplicationCMKId" {
  type        = string
  description = "Enter Aliases for custom KMS to encrypt Replication bucket"
}

variable "OriginalCMKId" {
  type        = string
  description = "Enter Aliases for custom KMS to encrypt Source bucket"
}

variable "EC2RoleToRunBackup" {
  type        = string
  description = "Enter EC2 Role Arn need to copy the Backup to S3"
}

variable "KMSAdminRole" {
  type        = string
  description = "Enter Role ARN for KMS Admin"
}

variable "BucketNameForLambdaCode" {
  type        = string
  description = "Enter The bucket name where source code of Lambda to be loaded"
}

/* terraform {
  required_version = ">= 1.0.0"
} */

locals {
  parameter_groups = [
    {
      label      = "Source Bucket"
      parameters = ["OriginalBucketName", "OriginalCMKId"]
    },
    {
      label      = "Replication Bucket"
      parameters = ["RepRegion", "ReplicationBucketName", "ReplicationCMKId", "EC2RoleToRunBackup", "KMSAdminRole"]
    },
    {
      label      = "Lambda Bucket"
      parameters = ["BucketNameForLambdaCode"]
    }
  ]
}

/* data "aws_ssm_parameter" "ssm_template_metadata" {
  name = "/aws/service/cloudformation/template/parameter_types"
}

resource "aws_ssm_parameter" "template_metadata_parameters" {
  count = length(locals.parameter_groups)

  name        = "/aws/service/cloudformation/template/parameter_types/${count.index}"
  description = "CloudFormation template parameter types"
  type        = "String"
  value       = jsonencode({
    "Label"      : { "default" : local.parameter_groups[count.index].label },
    "Parameters" : local.parameter_groups[count.index].parameters
  }) */

/* provider_meta "metadata" {
    ParameterGroups = [
      {
        Label = {
          default = "Source Bucket"
        }
        Parameters = [
          "OriginalBucketName",
          "OriginalCMKId"
        ]
      },
      {
        Label = {
          default = "Replication Bucket"
        }
        Parameters = [
          "RepRegion",
          "ReplicationBucketName",

          "ReplicationCMKId",
          "EC2RoleToRunBackup",
          "KMSAdminRole"
        ]
      },
      {
        Label = {
          default = "Lambda Bucket"
        }
        Parameters = [
          "BucketNameForLambdaCode"
        ]
      }
    ]
  }
} */
resource "aws_kms_key" "S3KmsSourceBucket" {
  description         = "To Encrypt S3 backup bucket"
  enable_key_rotation = true

  tags = {
    "Name" = "KMS Key For Source S3 Backup"
  }

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Id": "kms-key-policy",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${aws_iam_root_user.arn}"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow administration of the key",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${aws_iam_role.KMSAdminRole.arn}"
      },
      "Action": [
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:Put*",
        "kms:Update*",
        "kms:Revoke*",
        "kms:Disable*",
        "kms:Get*",
        "kms:Delete*",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion"
      ],
      "Resource": "*"
    },
    {
      "Sid": "Allow use of the key",
      "Effect": "Allow",
      "Principal": {
        "AWS": "${aws_iam_role.EC2RoleToRunBackup.arn}"
      },
      "Action": [
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey",
        "kms:GenerateDataKeyWithoutPlaintext"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}
resource "aws_kms_alias" "CreateAliasKMSkey" {
  depends_on = [aws_kms_key.S3KmsSourceBucket]

  alias_name   = "alias/${aws_kms_key.S3KmsSourceBucket.key_id}"
  target_key_id = aws_kms_key.S3KmsSourceBucket.key_id
}

resource "aws_iam_role" "LambdaExecutionRole" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ]
}
EOF
  path = "/"
}

resource "aws_s3_bucket" "OriginalBucket" {
  depends_on = [
    aws_s3_bucket.TriggerLambdaBucketLiveCycle,
    aws_kms_key.S3KmsSourceBucket,
    aws_kms_alias.CreateAliasKMSkey
  ]

  bucket = var.OriginalBucketName

  replication_configuration {
    role = aws_iam_role.S3ReplRole.arn

    rule {
      destination {
        bucket = "arn:aws:s3:::${var.ReplicationBucketName}"
        
        encryption_configuration {
          replica_kms_key_id = aws_kms_key.TriggerLambdaKmsKey.key_id
        }
      }

      id          = "BackupReplication"
      prefix      = ""
      status      = "Enabled"
      
      source_selection_criteria {
        sse_kms_encrypted_objects {
          status = "Enabled"
        }
      }
    }
  }

  versioning_configuration {
    status = "Enabled"
  }

  bucket_encryption {
    server_side_encryption_configuration {
      rule {
        apply_server_side_encryption_by_default {
          kms_master_key_id = aws_kms_key.S3KmsSourceBucket.key_id
          sse_algorithm     = "aws:kms"
        }
      }
    }
  }

  public_access_block_configuration {
    block_public_acls       = true
    ignore_public_acls      = true
    block_public_policy     = true
    restrict_public_buckets = true
  }

  lifecycle_configuration {
    rule {
      id      = "DAILY"
      prefix  = "DAILY/"
      status  = "Enabled"
      expiration_in_days = 365

      transition {
        days         = 10
        storage_class = "GLACIER"
      }
    }
  }
}
resource "aws_lambda_function" "ReplicationBucket" {
  depends_on = [aws_kms_key.TriggerLambdaKmsKey]

  filename      = "createDesbucket.zip"
  function_name = "bucketrepl"
  role          = aws_iam_role.LambdaExecutionRole.arn
  handler       = "bucketrepl.handler"
  runtime       = "nodejs8.10"
  timeout       = 60

  source_code_hash = filebase64sha256("createDesbucket.zip")
}

resource "custom_resource_lambda_trigger" "TriggerLambdaRepS3" {
  service_token        = aws_lambda_function.ReplicationBucket.arn
  dest_bucket_name     = var.ReplicationBucketName
  dest_bucket_region   = var.RepRegion
  dest_kms_id          = var.ReplicationCMKId
  account_id           = aws_caller_identity.current.account_id
  kms_admin_role       = var.KMSAdminRole
  kms_ec2_role         = var.EC2RoleToRunBackup
}

resource "aws_lambda_function" "ReplicationKmsKey" {
  filename      = "createbucket.zip"
  function_name = "create_kms"
  role          = aws_iam_role.LambdaExecutionRole.arn
  handler       = "create_kms.handler"
  runtime       = "nodejs8.10"
  timeout       = 60

  source_code_hash = filebase64sha256("createbucket.zip")
}
resource "aws_lambda_function" "ReplicationBucketVersion" {
  depends_on = [custom_resource_lambda_trigger.TriggerLambdaRepS3]

  filename      = "createbucket.zip"
  function_name = "bucketversion"
  role          = aws_iam_role.LambdaExecutionRole.arn
  handler       = "bucketversion.handler"
  runtime       = "nodejs8.10"
  timeout       = 60

  source_code_hash = filebase64sha256("createbucket.zip")
}

resource "custom_resource_lambda_trigger" "TriggerLambdaBucketVersion" {
  service_token        = aws_lambda_function.ReplicationBucketVersion.arn
  dest_bucket_name     = var.ReplicationBucketName
  dest_bucket_region   = var.RepRegion
  dest_kms_id          = var.ReplicationCMKId
  account_id           = aws_caller_identity.current.account_id
  kms_admin_role       = var.KMSAdminRole
  kms_ec2_role         = var.EC2RoleToRunBackup
}

resource "aws_lambda_function" "ReplicationBucketDenyNonEncrypt" {
  depends_on = [custom_resource_lambda_trigger.TriggerLambdaBucketVersion]

  filename      = "createbucket.zip"
  function_name = "denaynonencrypt"
  role          = aws_iam_role.LambdaExecutionRole.arn
  handler       = "denaynonencrypt.handler"
  runtime       = "nodejs8.10"
  timeout       = 60

  source_code_hash = filebase64sha256("createbucket.zip")
}
resource "custom_resource_lambda_trigger" "TriggerLambdaBucketDenyNonEcrypt" {
  service_token        = aws_lambda_function.ReplicationBucketDenyNonEncrypt.arn
  dest_bucket_name     = var.ReplicationBucketName
  dest_bucket_region   = var.RepRegion
  dest_kms_id          = var.ReplicationCMKId
  account_id           = aws_caller_identity.current.account_id
  kms_admin_role       = var.KMSAdminRole
  kms_ec2_role         = var.EC2RoleToRunBackup
}

resource "aws_lambda_function" "ReplicationBucketDefaultEncrypt" {
  depends_on = [custom_resource_lambda_trigger.TriggerLambdaBucketDenyNonEcrypt]

  filename      = "createbucket.zip"
  function_name = "defaulrencrypt"
  role          = aws_iam_role.LambdaExecutionRole.arn
  handler       = "defaulrencrypt.handler"
  runtime       = "nodejs8.10"
  timeout       = 60

  source_code_hash = filebase64sha256("createbucket.zip")
}

resource "custom_resource_lambda_trigger" "TriggerLambdaBucketDefaultEncrypt" {
  service_token        = aws_lambda_function.ReplicationBucketDefaultEncrypt.arn
  dest_bucket_name     = var.ReplicationBucketName
  dest_bucket_region   = var.RepRegion
  dest_kms_id          = var.ReplicationCMKId
  account_id           = aws_caller_identity.current.account_id
  kms_admin_role       = var.KMSAdminRole
  kms_ec2_role         = var.EC2RoleToRunBackup
}

resource "aws_lambda_function" "ReplicationBucketLiveCycle" {
  depends_on = [custom_resource_lambda_trigger.TriggerLambdaBucketDefaultEncrypt]

  filename      = "createbucket.zip"
  function_name = "lifecycle"
  role          = aws_iam_role.LambdaExecutionRole.arn
  handler       = "lifecycle.handler"
  runtime       = "nodejs8.10"
  timeout       = 60

  source_code_hash = filebase64sha256("createbucket.zip")
}
resource "custom_resource_lambda_trigger" "TriggerLambdaBucketLiveCycle" {
  service_token        = aws_lambda_function.ReplicationBucketLiveCycle.arn
  dest_bucket_name     = var.ReplicationBucketName
  dest_bucket_region   = var.RepRegion
  dest_kms_id          = var.ReplicationCMKId
  account_id           = aws_caller_identity.current.account_id
  kms_admin_role       = var.KMSAdminRole
  kms_ec2_role         = var.EC2RoleToRunBackup
}

resource "aws_iam_role" "S3ReplRole" {
  name = "S3ReplRole"
  path = "/service-role/"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
resource "aws_iam_managed_policy" "S3crrKmsForBucketPolicy" {
  name        = "S3crrKmsForBucketPolicy1"
  path        = "/service-role/"
  description = "S3crrKmsForBucketPolicy1"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:ListBucket",
        "s3:GetReplicationConfiguration",
        "s3:GetObjectVersionForReplication",
        "s3:GetObjectVersionAcl",
        "s3:GetObjectVersionTagging"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${var.OriginalBucketName}",
        "arn:aws:s3:::${var.OriginalBucketName}/*"
      ]
    },
    {
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete",
        "s3:ReplicateTags",
        "s3:GetObjectVersionTagging"
      ],
      "Effect": "Allow",
      "Condition": {
        "StringLikeIfExists": {
          "s3:x-amz-server-side-encryption": [
            "aws:kms",
            "AES256"
          ],
          "s3:x-amz-server-side-encryption-aws-kms-key-id": [
            "${aws_lambda_function.TriggerLambdaKmsKey.arn}"
          ]
        }
      },
      "Resource": "arn:aws:s3:::${var.ReplicationBucketName}/*"
    },
    {
      "Action": [
        "kms:Decrypt"
      ],
      "Effect": "Allow",
      "Condition": {
        "StringLike": {
          "kms:ViaService": "s3.${data.aws_region.current.name}.amazonaws.com",
          "kms:EncryptionContext:aws:s3:arn": [
            "arn:aws:s3:::${var.OriginalBucketName}/*"
          ]
        }
      },
      "Resource": "${aws_kms_key.S3KmsSourceBucket.arn}"
    },
    {
      "Action": [
        "kms:Encrypt"
      ],
      "Effect": "Allow",
      "Condition": {
        "StringLike": {
          "kms:ViaService": "s3.${var.RepRegion}.amazonaws.com",
          "kms:EncryptionContext:aws:s3:arn": [
            "arn:aws:s3:::${var.ReplicationBucketName}/*"
          ]
        }
      },
      "Resource": "${aws_lambda_function.TriggerLambdaKmsKey.arn}"
    }
  ]
}
EOF
}
resource "aws_s3_bucket_policy" "DenyPutNonEncrypt" {
  bucket = aws_s3_bucket.OriginalBucketName.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyIncorrectEncryptionHeader",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${var.OriginalBucketName}/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "aws:kms"
        }
      }
    },
    {
      "Sid": "DenyUnEncryptedObjectUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${var.OriginalBucketName}/*",
      "Condition": {
        "Null": {
          "s3:x-amz-server-side-encryption": true
        }
      }
    }
  ]
}
EOF
}
