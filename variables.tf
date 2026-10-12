variable "account_alias" {
  type        = string
  description = "account metadata friendly name for the aws account, used as the access analyzer name"
}
variable "manage_global_resources" {
  type        = bool
  default     = true
  description = "manage account-global resources (iam password policy, account-level s3 public access block). set to false on all but one instance when deploying this module to multiple regions"
}
variable "create_access_analyzer" {
  type        = bool
  default     = true
  description = "create iam access analyzer, defaults to true"
}
variable "create_s3_public_access_block" {
  type        = bool
  default     = true
  description = "create account-level s3 public access block, defaults to true, no longer really required since aws updated their default behavior. ignored when manage_global_resources is false"
}
variable "enable_ebs_encryption_by_default" {
  type        = bool
  default     = true
  description = "enable ebs encryption by default in this region. setting this to false after it was true disables ebs encryption by default"
}
variable "ebs_default_kms_key_arn" {
  type        = string
  default     = null
  description = "arn of a customer managed kms key to use for ebs encryption by default. defaults to null, which uses the aws managed aws/ebs key"
}
variable "ebs_snapshot_block_public_access" {
  type        = bool
  default     = true
  description = "block public sharing of ebs snapshots, defaults to true"
}
variable "ebs_snapshot_block_public_access_state" {
  type        = string
  default     = "block-all-sharing"
  description = "ebs snapshot block public access state, block-all-sharing or block-new-sharing"
  validation {
    condition     = contains(["block-all-sharing", "block-new-sharing"], var.ebs_snapshot_block_public_access_state)
    error_message = "ebs_snapshot_block_public_access_state must be block-all-sharing or block-new-sharing."
  }
}
variable "aws_ec2_image_block_public_access" {
  type        = bool
  default     = true
  description = "block public access to ec2 images, defaults to true"
}
variable "max_password_age" {
  type        = number
  default     = 90
  description = "maximum password age in days. set to 0 for passwords that never expire, as recommended by NIST SP 800-63B"
  validation {
    condition     = var.max_password_age >= 0 && var.max_password_age <= 1095
    error_message = "max_password_age must be between 0 (never expire) and 1095."
  }
}
variable "minimum_password_length" {
  type        = number
  default     = 14
  description = "minimum allowed length of password"
  validation {
    condition     = var.minimum_password_length >= 6 && var.minimum_password_length <= 128
    error_message = "minimum_password_length must be between 6 and 128."
  }
}
variable "password_history" {
  type        = number
  default     = 24
  description = "number of previous passwords retained in history to prevent reuse of passwords, CIS recommends 24"
  validation {
    condition     = var.password_history >= 1 && var.password_history <= 24
    error_message = "password_history must be between 1 and 24."
  }
}
variable "vpc_block_public_access_exclusion" {
  type        = map(string)
  default     = {}
  description = "map of vpc ids to block public access exclusion mode, e.g. { \"vpc-12345678\" = \"allow-bidirectional\" }"
  validation {
    condition     = alltrue([for mode in values(var.vpc_block_public_access_exclusion) : contains(["allow-bidirectional", "allow-egress"], mode)])
    error_message = "vpc_block_public_access_exclusion values must be allow-bidirectional or allow-egress."
  }
}
variable "vpc_internet_gateway_block_mode" {
  type        = string
  default     = "block-bidirectional"
  description = "vpc internet gateway block mode, can be block-bidirectional, block-ingress, or off"
  validation {
    condition     = contains(["block-bidirectional", "block-ingress", "off"], var.vpc_internet_gateway_block_mode)
    error_message = "vpc_internet_gateway_block_mode must be block-bidirectional, block-ingress, or off."
  }
}
variable "guardduty_detector_id" {
  type        = string
  default     = null
  description = "id of the existing guardduty detector in this region. when set, findings are exported to the module's s3 bucket. the plan fails if the detector does not exist"
}
variable "guardduty_findings_retention_days" {
  type        = number
  default     = null
  description = "days to retain guardduty findings (current and noncurrent versions) in the findings bucket. defaults to null, which retains findings indefinitely"
  validation {
    condition     = var.guardduty_findings_retention_days == null || try(var.guardduty_findings_retention_days >= 1, false)
    error_message = "guardduty_findings_retention_days must be null or at least 1."
  }
}
variable "kms_alias_name" {
  type        = string
  default     = "alias/security-key"
  description = "alias for the security kms key. kms aliases are regional, so this only needs changing if the module is deployed more than once in the same region"
  validation {
    condition     = startswith(var.kms_alias_name, "alias/") && !startswith(var.kms_alias_name, "alias/aws/")
    error_message = "kms_alias_name must start with alias/ and must not start with alias/aws/."
  }
}
variable "tags" {
  type        = map(string)
  default     = {}
  description = "tags to apply to all resources"
}
