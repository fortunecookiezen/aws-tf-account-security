# aws-tf-account-security

Terraform project for account security baseline. Include this module in your project to set security best practices for your account.

<!-- BEGIN_TF_DOCS -->


## Example

```hcl
module "security-baseline" {
  source                        = "github.com/fortunecookiezen/aws-tf-account-security"
  account_alias                 = "my-account-alias"
  create_access_analyzer        = true
  create_s3_public_access_block = true
}

```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.60.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 3.62.0 |

## Modules

No modules.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_alias"></a> [account\_alias](#input\_account\_alias) | n/a | `string` | n/a | yes |
| <a name="input_create_access_analyzer"></a> [create\_access\_analyzer](#input\_create\_access\_analyzer) | n/a | `bool` | `true` | no |
| <a name="input_create_s3_public_access_block"></a> [create\_s3\_public\_access\_block](#input\_create\_s3\_public\_access\_block) | n/a | `bool` | `true` | no |

## Resources

| Name | Type |
|------|------|
| [aws_accessanalyzer_analyzer.analyzer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/accessanalyzer_analyzer) | resource |
| [aws_ebs_encryption_by_default.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_encryption_by_default) | resource |
| [aws_guardduty_publishing_destination.account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_publishing_destination) | resource |
| [aws_iam_account_password_policy.policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_account_password_policy) | resource |
| [aws_kms_alias.security_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.security](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_account_public_access_block.example](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_account_public_access_block) | resource |
| [aws_s3_bucket.guardduty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.guardduty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.guardduty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_ebs_encryption_by_default.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ebs_encryption_by_default) | data source |
| [aws_guardduty_detector.account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/guardduty_detector) | data source |
| [aws_iam_policy_document.bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.key_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ebs_encryption_by_default"></a> [ebs\_encryption\_by\_default](#output\_ebs\_encryption\_by\_default) | n/a |
<!-- END_TF_DOCS -->
