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
