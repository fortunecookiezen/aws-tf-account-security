terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.60.0"
    }
  }
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_guardduty_detector" "account" {}
# Account Password Policy
resource "aws_iam_account_password_policy" "policy" {
  minimum_password_length        = 16
  require_lowercase_characters   = true
  require_numbers                = true
  require_uppercase_characters   = true
  require_symbols                = true
  allow_users_to_change_password = true
}
# GuardDuty findings bucket
resource "aws_s3_bucket" "guardduty" {
  bucket = "guardduty-findings-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.security.id
      }
    }
  }
  tags = {
    LastUpdatedBy = data.aws_caller_identity.current.user_id
    # LastUpdate    = formatdate("MMM DD YYYY hh:mm ZZZ", timestamp())
  }
  versioning {
    enabled = true
  }
}
resource "aws_s3_bucket_public_access_block" "guardduty" {
  bucket                  = aws_s3_bucket.guardduty.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_policy" "guardduty" {
  depends_on = [
    aws_s3_bucket_public_access_block.guardduty
  ]
  bucket = aws_s3_bucket.guardduty.id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "DefaultBucketPolicy"
    Statement = [
      {
        Sid    = "AllowPutObject"
        Effect = "Allow"
        Principal = {
          Service = ["guardduty.amazonaws.com"]
        }
        Action = [
          "s3:PutObject"
        ]
        Resource = [
          "${aws_s3_bucket.guardduty.arn}/*"
        ]
      },
      {
        Sid    = "AllowGetBucketLocation"
        Effect = "Allow"
        Principal = {
          Service = ["guardduty.amazonaws.com"]
        }
        Action = ["s3:GetBucketLocation"]
        Resource = [
          "${aws_s3_bucket.guardduty.arn}"
        ]
      },
      {
        Sid       = "DenyNonHttpsAccess"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "${aws_s3_bucket.guardduty.arn}",
          "${aws_s3_bucket.guardduty.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
resource "aws_kms_key" "security" {
  description             = "Security ${data.aws_region.current.name} Ecryption Key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags = {
    LastUpdatedBy = data.aws_caller_identity.current.user_id
  }
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "SecurityKeyPolicy"
    Statement = [
      {
        Sid    = "AllowGuardDutyEncryption"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey"
        ]
        Resource = [
          "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"
        ]
      },
      {
        Sid    = "AllowKeyAdministration"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "kms:*"
        ]
        Resource = [
          "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"
        ]
      }
    ]
  })
}
resource "aws_guardduty_publishing_destination" "account" {
  count           = data.aws_guardduty_detector.account.id != "" ? 1 : 0
  detector_id     = data.aws_guardduty_detector.account.id
  destination_arn = aws_s3_bucket.guardduty.arn
  kms_key_arn     = aws_kms_key.security.arn
}
