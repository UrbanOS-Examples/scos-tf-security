locals {
  s3_key_prefix = "root-trail"
}

resource "aws_cloudtrail" "root_trail" {
  name                          = "root-trail"
  s3_bucket_name                = aws_s3_bucket.root_trail_bucket.id
  s3_key_prefix                 = local.s3_key_prefix
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.root_trail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.root_trail_iam_role.arn
  depends_on                    = [aws_s3_bucket_policy.root_trail_bucket_policy]
}

resource "aws_cloudwatch_log_group" "root_trail" {
  name              = "root-trail"
  retention_in_days = "90"
}

resource "aws_cloudwatch_log_metric_filter" "root_filter" {
  name    = "RootAccess"
  pattern = <<FILTER_PATTERN
  {$.userIdentity.type="Root" && $.userIdentity.invokedBy NOT EXISTS && $.eventType !="AwsServiceEvent"}
  
FILTER_PATTERN

  log_group_name = aws_cloudwatch_log_group.root_trail.name

  metric_transformation {
    name      = "RootAccess"
    namespace = "LogMetrics"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "root-access-alarm" {
  alarm_name          = "root-access-alarm"
  metric_name         = "RootAccess"
  comparison_operator = "GreaterThanThreshold"
  threshold           = "0"
  namespace           = "LogMetrics"
  statistic           = "Sum"
  evaluation_periods  = "1"
  period              = "10"
  alarm_description   = "This metric monitors root account access"
  alarm_actions       = [var.alert_handler_sns_topic_arn]
}

resource "aws_s3_bucket" "root_trail_bucket" {
  bucket        = "scos-${terraform.workspace}-${data.aws_caller_identity.current.account_id}-root-trail-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_policy" "root_trail_bucket_policy" {
  bucket = aws_s3_bucket.root_trail_bucket.id
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "${aws_s3_bucket.root_trail_bucket.arn}"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "${aws_s3_bucket.root_trail_bucket.arn}/${local.s3_key_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY

}

resource "aws_iam_policy" "root_trail_iam_policy" {
  name = "${terraform.workspace}_root_trail_iam_policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailCreateLogStream",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream"
      ],
      "Resource": [
        "${aws_cloudwatch_log_group.root_trail.arn}:*"
      ]
    },
    {
      "Sid": "AWSCloudTrailPutLogEvents",
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents"
      ],
      "Resource": [
        "${aws_cloudwatch_log_group.root_trail.arn}:*"
      ]
    }
  ]
}
EOF

}

resource "aws_iam_role" "root_trail_iam_role" {
  name = "${terraform.workspace}_root_trail_iam_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

}

resource "aws_iam_role_policy_attachment" "root_trail_rolepolicy_attachment" {
  role       = aws_iam_role.root_trail_iam_role.name
  policy_arn = aws_iam_policy.root_trail_iam_policy.arn
}

