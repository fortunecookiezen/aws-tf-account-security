terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
# discovered data resources to make configuration easier
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_guardduty_detector" "account" {}
data "aws_ebs_encryption_by_default" "current" {}
# Account Password Policy
resource "aws_iam_account_password_policy" "policy" {
  max_password_age               = var.max_password_age
  minimum_password_length        = var.minimum_password_length
  require_lowercase_characters   = true
  require_numbers                = true
  require_uppercase_characters   = true
  require_symbols                = true
  allow_users_to_change_password = true
  password_reuse_prevention      = var.password_history
}
# Account-scope Access Analyzer
resource "aws_accessanalyzer_analyzer" "analyzer" {
  count         = var.create_access_analyzer ? 1 : 0
  analyzer_name = var.account_alias
  type          = "ACCOUNT"
  tags = merge({
    Name = "Access Analyzer"
  }, var.tags)
}
resource "aws_ebs_encryption_by_default" "this" {
  count   = data.aws_ebs_encryption_by_default.current.enabled ? 0 : 1
  enabled = true
}
# resource "aws_ebs_snapshot_block_public_access" "this" {
#   count = var.ebs_snapshot_block_all_sharing ? 1 : 0
#   state = "block-all-sharing"
# }
# Prevent making AMIs publicly accessible in the region and account for which the provider is configured
resource "aws_ec2_image_block_public_access" "this" {
  state = var.aws_ec2_image_block_public_access ? "block-new-sharing" : "unblocked"
}
resource "aws_s3_account_public_access_block" "this" {
  count                   = var.create_s3_public_access_block ? 1 : 0
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_vpc_block_public_access_options" "this" {
  count                       = var.vpc_internet_gateway_block_mode != "off" ? 1 : 0
  internet_gateway_block_mode = var.vpc_internet_gateway_block_mode # block-bidrectional, "block-ingress", or "off"
}
resource "aws_vpc_block_public_access_exclusion" "this" {
  for_each                        = var.vpc_block_public_access_exclusion
  vpc_id                          = each.key
  internet_gateway_exclusion_mode = each.value # "allow-bidirectional" or "allow-egress"
  tags                            = merge({}, var.tags)
}
# GuardDuty findings bucket, we don't log access to this.
resource "aws_s3_bucket" "guardduty" {
  #tfsec:ignore:aws-s3-enable-bucket-logging
  bucket = "guardduty-findings-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  tags = merge({
    Name = "GuardDuty Findings Bucket"
  }, var.tags)
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
resource "aws_s3_bucket_server_side_encryption_configuration" "guardduty" {
  bucket = aws_s3_bucket.guardduty.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.security.arn
      sse_algorithm     = "aws:kms"
    }
  }
}
resource "aws_s3_bucket_versioning" "guardduty" {
  bucket = aws_s3_bucket.guardduty.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_kms_alias" "security_key" {
  name          = "alias/security-key"
  target_key_id = aws_kms_key.security.key_id
}
resource "aws_kms_key" "security" {
  description             = "Security ${data.aws_region.current.name} Ecryption Key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags = merge({
    Name = "Security Key"
  }, var.tags)
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
