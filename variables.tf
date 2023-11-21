variable "account_alias" {
  type = string
  description = "account metadata friendly name for the aws account"
}
variable "create_access_analyzer" {
  type    = bool
  default = true
  description = "create iam access analyzer, defaults to true"
}
variable "create_s3_public_access_block" {
  type    = bool
  default = true
  description = "create account-level s3 public access block, defaults to true, no longer really required since aws updated their default behavior"
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