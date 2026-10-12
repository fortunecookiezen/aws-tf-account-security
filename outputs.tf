output "ebs_encryption_by_default" {
  value       = var.enable_ebs_encryption_by_default
  description = "whether this module enables ebs encryption by default in this region"
}
output "kms_key_arn" {
  value       = aws_kms_key.security.arn
  description = "arn of the security kms key"
}
output "kms_key_alias" {
  value       = aws_kms_alias.security_key.name
  description = "alias of the security kms key"
}
output "guardduty_findings_bucket_name" {
  value       = aws_s3_bucket.guardduty.id
  description = "name of the guardduty findings bucket"
}
output "guardduty_findings_bucket_arn" {
  value       = aws_s3_bucket.guardduty.arn
  description = "arn of the guardduty findings bucket"
}
output "access_analyzer_arn" {
  value       = try(aws_accessanalyzer_analyzer.analyzer[0].arn, null)
  description = "arn of the access analyzer, null when not created"
}
