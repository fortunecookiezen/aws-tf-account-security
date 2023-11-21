variable "account_alias" {
  type = string
}
variable "create_access_analyzer" {
  type    = bool
  default = true
}
variable "create_s3_public_access_block" {
  type    = bool
  default = true
}
variable "max_password_age" {
  type        = number
  default     = 90
  description = "maximum password age allowed"
}
variable "minimum_password_length" {
  type        = number
  default     = 8
  description = "minimum allowed length of password"
}
variable "password_reuse_prevention" {
  type        = number
  default     = 8
  description = "number of previous passwords retained in history to prevent reuse of passwords"
}