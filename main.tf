# discovered data resources to make configuration easier
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}
# looking up the detector fails the plan if the supplied detector id does not exist in this region
data "aws_guardduty_detector" "account" {
  count = var.guardduty_detector_id != null ? 1 : 0
  id    = var.guardduty_detector_id
}
locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region
  # scope guardduty service access to this account's detector, or any detector in this account/region when none is supplied
  guardduty_detector_arn = var.guardduty_detector_id != null ? data.aws_guardduty_detector.account[0].arn : "arn:${local.partition}:guardduty:${local.region}:${local.account_id}:detector/*"
}
# Account Password Policy (global)
moved {
  from = aws_iam_account_password_policy.policy
  to   = aws_iam_account_password_policy.policy[0]
}
resource "aws_iam_account_password_policy" "policy" {
  count                          = var.manage_global_resources ? 1 : 0
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
# destroying this resource disables ebs encryption by default, so it must not depend on current state
resource "aws_ebs_encryption_by_default" "this" {
  count   = var.enable_ebs_encryption_by_default ? 1 : 0
  enabled = true
}
resource "aws_ebs_default_kms_key" "this" {
  count   = var.ebs_default_kms_key_arn != null ? 1 : 0
  key_arn = var.ebs_default_kms_key_arn
}
resource "aws_ebs_snapshot_block_public_access" "this" {
  count = var.ebs_snapshot_block_public_access ? 1 : 0
  state = var.ebs_snapshot_block_public_access_state
}
# Prevent making AMIs publicly accessible in the region and account for which the provider is configured
resource "aws_ec2_image_block_public_access" "this" {
  state = var.aws_ec2_image_block_public_access ? "block-new-sharing" : "unblocked"
}
# Account-level S3 public access block (global)
resource "aws_s3_account_public_access_block" "this" {
  count                   = var.manage_global_resources && var.create_s3_public_access_block ? 1 : 0
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_vpc_block_public_access_options" "this" {
  count                       = var.vpc_internet_gateway_block_mode != "off" ? 1 : 0
  internet_gateway_block_mode = var.vpc_internet_gateway_block_mode # "block-bidirectional", "block-ingress", or "off"
}
resource "aws_vpc_block_public_access_exclusion" "this" {
  for_each                        = var.vpc_block_public_access_exclusion
  vpc_id                          = each.key
  internet_gateway_exclusion_mode = each.value # "allow-bidirectional" or "allow-egress"
  tags                            = merge({}, var.tags)
}
# GuardDuty findings bucket, we don't log access to this.
#trivy:ignore:AVD-AWS-0089
resource "aws_s3_bucket" "guardduty" {
  bucket = "guardduty-findings-${local.account_id}-${local.region}"
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
  policy = data.aws_iam_policy_document.bucket_policy.json
}
resource "aws_s3_bucket_server_side_encryption_configuration" "guardduty" {
  bucket = aws_s3_bucket.guardduty.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.security.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}
resource "aws_s3_bucket_versioning" "guardduty" {
  bucket = aws_s3_bucket.guardduty.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_lifecycle_configuration" "guardduty" {
  count  = var.guardduty_findings_retention_days != null ? 1 : 0
  bucket = aws_s3_bucket.guardduty.id
  rule {
    id     = "expire-findings"
    status = "Enabled"
    filter {}
    expiration {
      days = var.guardduty_findings_retention_days
    }
    noncurrent_version_expiration {
      noncurrent_days = var.guardduty_findings_retention_days
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
  depends_on = [aws_s3_bucket_versioning.guardduty]
}
resource "aws_kms_alias" "security_key" {
  name          = var.kms_alias_name
  target_key_id = aws_kms_key.security.key_id
}
resource "aws_kms_key" "security" {
  description             = "Security ${local.region} Encryption Key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags = merge({
    Name = "Security Key"
  }, var.tags)
  policy = data.aws_iam_policy_document.key_policy.json
}
resource "aws_guardduty_publishing_destination" "account" {
  count           = var.guardduty_detector_id != null ? 1 : 0
  detector_id     = var.guardduty_detector_id
  destination_arn = aws_s3_bucket.guardduty.arn
  kms_key_arn     = aws_kms_key.security.arn
  # guardduty validates bucket and key access when the destination is created
  depends_on = [
    aws_s3_bucket_policy.guardduty,
    aws_s3_bucket_server_side_encryption_configuration.guardduty,
  ]
}
# Unused access analyzer, billed per iam role and user analyzed in each region it is created
resource "aws_accessanalyzer_analyzer" "unused_access" {
  count         = var.manage_global_resources && var.create_unused_access_analyzer ? 1 : 0
  analyzer_name = "${var.account_alias}-unused-access"
  type          = "ACCOUNT_UNUSED_ACCESS"
  configuration {
    unused_access {
      unused_access_age = var.unused_access_age_days
    }
  }
  tags = merge({
    Name = "Unused Access Analyzer"
  }, var.tags)
}
# Account alias (global)
resource "aws_iam_account_alias" "this" {
  count         = var.manage_global_resources && var.create_account_alias ? 1 : 0
  account_alias = var.account_alias
  lifecycle {
    precondition {
      condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.account_alias))
      error_message = "account_alias must be 3-63 lowercase letters, numbers, or hyphens, and must not start or end with a hyphen to be used as the iam account alias."
    }
  }
}
# Security alternate contact (global)
resource "aws_account_alternate_contact" "security" {
  count                  = var.manage_global_resources && var.security_contact != null ? 1 : 0
  alternate_contact_type = "SECURITY"
  name                   = var.security_contact.name
  title                  = var.security_contact.title
  email_address          = var.security_contact.email_address
  phone_number           = var.security_contact.phone_number
}
# Require IMDSv2 for new instances that don't set their own metadata options
resource "aws_ec2_instance_metadata_defaults" "this" {
  count                       = var.require_imdsv2 ? 1 : 0
  http_tokens                 = "required"
  http_put_response_hop_limit = var.imds_hop_limit
}
# Prevent public sharing of ssm documents
resource "aws_ssm_service_setting" "document_public_sharing" {
  count         = var.ssm_block_public_document_sharing ? 1 : 0
  setting_id    = "arn:${local.partition}:ssm:${local.region}:${local.account_id}:servicesetting/ssm/documents/console/public-sharing-permission"
  setting_value = "Disable"
}
# Block emr clusters with security groups open to the internet, with no port exceptions
resource "aws_emr_block_public_access_configuration" "this" {
  count                             = var.emr_block_public_access ? 1 : 0
  block_public_security_group_rules = true
}
# Remove all rules from the default vpc's default security group
data "aws_vpcs" "default" {
  count = var.restrict_default_security_group ? 1 : 0
  filter {
    name   = "is-default"
    values = ["true"]
  }
}
resource "aws_default_security_group" "default_vpc" {
  count  = var.restrict_default_security_group ? length(data.aws_vpcs.default[0].ids) : 0
  vpc_id = data.aws_vpcs.default[0].ids[count.index]
  # empty lists, rather than omitting the arguments, make terraform remove rules added outside of terraform
  ingress = []
  egress  = []
  tags = merge({
    Name = "default - restricted"
  }, var.tags)
}
