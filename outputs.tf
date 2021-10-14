output "ebs_encryption_by_default" {
  value = data.ebs_encryption_by_default.current.enabled
}
