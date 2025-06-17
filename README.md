# aws-tf-account-security

Terraform project for account security baseline. Include this module in your project to set security best practices for your account.

<!-- BEGIN_TF_DOCS -->


## Example

```hcl
module "security-baseline" {
  source                            = "github.com/fortunecookiezen/aws-tf-account-security"
  account_alias                     = "my-account-alias"
  create_access_analyzer            = true
  create_s3_public_access_block     = true
  ebs_snapshot_block_all_sharing    = true
  aws_ec2_image_block_public_access = true
  minimum_password_length           = 16
  password_history                  = 8
  vpc_internet_gateway_block_mode   = "off"
  vpc_block_public_access_exclusion = {
    "vpc-0f54aefb63f391295" = "allow-egress"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |

## Modules

No modules.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_alias"></a> [account\_alias](#input\_account\_alias) | account metadata friendly name for the aws account | `string` | n/a | yes |
| <a name="input_aws_ec2_image_block_public_access"></a> [aws\_ec2\_image\_block\_public\_access](#input\_aws\_ec2\_image\_block\_public\_access) | block public access to ec2 images, defaults to true | `bool` | `true` | no |
| <a name="input_create_access_analyzer"></a> [create\_access\_analyzer](#input\_create\_access\_analyzer) | create iam access analyzer, defaults to true | `bool` | `true` | no |
| <a name="input_create_s3_public_access_block"></a> [create\_s3\_public\_access\_block](#input\_create\_s3\_public\_access\_block) | create account-level s3 public access block, defaults to true, no longer really required since aws updated their default behavior | `bool` | `true` | no |
| <a name="input_ebs_snapshot_block_public_access"></a> [ebs\_snapshot\_block\_public\_access](#input\_ebs\_snapshot\_block\_public\_access) | block all sharing of ebs snapshots, defaults to true | `bool` | `true` | no |
| <a name="input_max_password_age"></a> [max\_password\_age](#input\_max\_password\_age) | maximum password age allowed | `number` | `90` | no |
| <a name="input_minimum_password_length"></a> [minimum\_password\_length](#input\_minimum\_password\_length) | minimum allowed length of password | `number` | `14` | no |
| <a name="input_password_history"></a> [password\_history](#input\_password\_history) | number of previous passwords retained in history to prevent reuse of passwords | `number` | `8` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc_block_public_access_exclusion"></a> [vpc\_block\_public\_access\_exclusion](#input\_vpc\_block\_public\_access\_exclusion) | map of vpc ids to block public access exclusion mode, e.g. { "vpc-12345678" = "allow-bidirectional" } | `map(string)` | `{}` | no |
| <a name="input_vpc_internet_gateway_block_mode"></a> [vpc\_internet\_gateway\_block\_mode](#input\_vpc\_internet\_gateway\_block\_mode) | vpc internet gateway block mode, can be block-bidirectional, block-ingress, or off | `string` | `"block-bidirectional"` | no |

## Resources

| Name | Type |
|------|------|
| [aws_accessanalyzer_analyzer.analyzer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/accessanalyzer_analyzer) | resource |
| [aws_ebs_encryption_by_default.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_encryption_by_default) | resource |
| [aws_ebs_snapshot_block_public_access.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_snapshot_block_public_access) | resource |
| [aws_ec2_image_block_public_access.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_image_block_public_access) | resource |
| [aws_guardduty_publishing_destination.account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_publishing_destination) | resource |
| [aws_iam_account_password_policy.policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_account_password_policy) | resource |
| [aws_kms_alias.security_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.security](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_account_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_account_public_access_block) | resource |
| [aws_s3_bucket.guardduty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_policy.guardduty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.guardduty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.guardduty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.guardduty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_vpc_block_public_access_exclusion.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_block_public_access_exclusion) | resource |
| [aws_vpc_block_public_access_options.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_block_public_access_options) | resource |
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
