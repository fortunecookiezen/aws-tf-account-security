output "ebs_encryption_by_default" {
  value = data.aws_ebs_encryption_by_default.current.enabled
}
