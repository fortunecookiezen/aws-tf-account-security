variable "account_alias" {
  type        = string
  description = "account metadata friendly name for the aws account"
}
variable "create_access_analyzer" {
  type        = bool
  default     = true
  description = "create iam access analyzer, defaults to true"
}
variable "create_s3_public_access_block" {
  type        = bool
  default     = true
  description = "create account-level s3 public access block, defaults to true, no longer really required since aws updated their default behavior"
}
variable "ebs_snapshot_block_all_sharing" {
  type        = bool
  default     = true
  description = "block all sharing of ebs snapshots, defaults to true"
}
variable "aws_ec2_image_block_public_access" {
  type        = bool
  default     = true
  description = "block public access to ec2 images, defaults to true"
}
variable "max_password_age" {
  type        = number
  default     = 90
  description = "maximum password age allowed"
}
variable "minimum_password_length" {
  type        = number
  default     = 14
  description = "minimum allowed length of password"
}
variable "password_history" {
  type        = number
  default     = 8
  description = "number of previous passwords retained in history to prevent reuse of passwords"
}
variable "vpc_block_public_access_exclusion" {
  type        = map(string)
  default     = {}
  description = "map of vpc ids to block public access exclusion mode, e.g. { \"vpc-12345678\" = \"allow-bidirectional\" }"
}
variable "vpc_internet_gateway_block_mode" {
  type        = string
  default     = "block-bidirectional"
  description = "vpc internet gateway block mode, can be block-bidirectional, block-ingress, or off"
}
variable "tags" {
  type        = map(string)
  default     = {}
  description = "tags to apply to all resources"
}