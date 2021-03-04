variable "force_destroy_s3_bucket" {
  description = "A boolean that indicates all objects (including any locked objects) should be deleted from the bucket so that the bucket can be destroyed without error. These objects are not recoverable."
  default     = false
}

variable "alert_handler_sns_topic_arn" {
  description = "An alert handler topic ARN for sending alerts"
}

data "aws_caller_identity" "current" {
}

data "aws_region" "current" {
}

resource "aws_securityhub_account" "default" {
  depends_on = [
    aws_config_configuration_recorder.default,
    aws_config_delivery_channel.default,
  ]
}

resource "aws_securityhub_standards_subscription" "aws_foundational" {
  depends_on    = [aws_securityhub_account.default]
  standards_arn = "arn:aws:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
}

resource "aws_securityhub_standards_subscription" "cis" {
  depends_on    = [aws_securityhub_account.default]
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"
}

# THESE CREATE MAJOR FLAKINESS AND ARE ON BY DEFAULT. LEAVING HERE FOR REFERENCE
# resource "aws_securityhub_product_subscription" "inspector" {
#   depends_on  = ["aws_securityhub_account.default"]
#   product_arn = "arn:aws:securityhub:${data.aws_region.current.name}::product/aws/inspector"
# }

# resource "aws_securityhub_product_subscription" "guardduty" {
#   depends_on  = ["aws_securityhub_account.default"]
#   product_arn = "arn:aws:securityhub:${data.aws_region.current.name}::product/aws/guardduty"
# }

resource "aws_cloudwatch_event_rule" "guardduty" {
  name        = "${terraform.workspace}-guardduty"
  description = "Capture whenever a GuardDuty event is seen"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.guardduty"
  ]
}
PATTERN

}

resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty.name
  target_id = "GuardDutyToSNS"
  arn       = var.alert_handler_sns_topic_arn
}

resource "aws_iam_service_linked_role" "config" {
  aws_service_name = "config.amazonaws.com"
  custom_suffix    = terraform.workspace
}

resource "aws_config_configuration_recorder" "default" {
  name     = "default"
  role_arn = aws_iam_service_linked_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "default" {
  name           = "default"
  s3_bucket_name = aws_s3_bucket.config.bucket
  depends_on     = [aws_config_configuration_recorder.default]
}

resource "aws_s3_bucket" "config" {
  bucket = "config-bucket-${data.aws_caller_identity.current.account_id}"
  acl    = "private"

  force_destroy = var.force_destroy_s3_bucket

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket = aws_s3_bucket.config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "config" {
  depends_on = [aws_s3_bucket_public_access_block.config]

  bucket = aws_s3_bucket.config.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSConfigBucketPermissionsCheck",
      "Effect": "Allow",
      "Principal": {
        "Service": "config.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "${aws_s3_bucket.config.arn}"
    },
    {
      "Sid": "AWSConfigBucketDelivery",
      "Effect": "Allow",
      "Principal": {
        "Service": "config.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "${aws_s3_bucket.config.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    },
    {
      "Sid": "AllowSSLRequestsOnly",
      "Action": "s3:*",
      "Effect": "Deny",
      "Resource": "${aws_s3_bucket.config.arn}",
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      },
      "Principal": "*"
    }
  ]
}
POLICY

}

