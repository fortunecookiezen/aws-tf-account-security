# aws-tf-account-security

Terraform project for account security baseline. Include this module in your project to set security best practices for your account.

Most controls are regional. To cover multiple regions, instantiate the module once per region and set `manage_global_resources = false` on all but one instance so account-global resources (IAM password policy, account-level S3 public access block, account alias, security alternate contact, and the unused access analyzer) are only managed once.

CloudTrail, AWS Config, and Security Hub are intentionally out of scope; they are usually managed centrally by AWS Organizations.

## Changes in v4.1

New controls, enabled by default in each region the module is deployed to. Each can be disabled:

- `require_imdsv2`: new EC2 instances that don't set their own metadata options require IMDSv2, with a hop limit of 2 (`imds_hop_limit`) so containers on EC2 can still reach the metadata service. Workloads that still use IMDSv1 will fail to get credentials on newly launched instances.
- `ssm_block_public_document_sharing`: blocks public sharing of SSM documents.
- `emr_block_public_access`: blocks EMR clusters with security groups that allow public inbound access, with no port exceptions (the AWS default allows port 22).
- `restrict_default_security_group`: removes all rules from the default VPC's default security group (CIS 5.4). Does nothing when there is no default VPC. Disabling this stops managing the group but does not restore its rules.

New opt-in features (global, ignored when `manage_global_resources` is false):

- `create_account_alias`: sets the IAM account alias to `account_alias`.
- `security_contact`: manages the security alternate contact. Leave unset when the organization management account sets it.
- `create_unused_access_analyzer`: creates a paid unused access analyzer (`unused_access_age_days`, default 90).

New utility script: `scripts/delete-default-vpcs.sh` (see [Deleting default VPCs](#deleting-default-vpcs)).

## Deleting default VPCs

This module doesn't delete default VPCs. Instead, the repo includes a script that does: [`scripts/delete-default-vpcs.sh`](scripts/delete-default-vpcs.sh). It deletes the default VPC (internet gateway, subnets, then the VPC) in every enabled region of the account the current AWS credentials belong to.

```sh
./scripts/delete-default-vpcs.sh                  # dry run, the default: shows what would be deleted
./scripts/delete-default-vpcs.sh --execute        # deletes after you type the account id to confirm
./scripts/delete-default-vpcs.sh --execute --yes  # deletes without a prompt, for automation
```

Before deleting anything, the script skips a default VPC that has network interfaces or anything else that would block deletion (non-default security groups, route tables or network ACLs, VPC endpoints, or an attached VPN gateway). It also skips regions it can't query, such as regions denied by an SCP. It exits non-zero only if a deletion fails partway through.

Run it once per account; it's independent of the Terraform module. If the module has `restrict_default_security_group` enabled, the next plan after deleting a default VPC drops the default security group from state with no changes in AWS. To recreate a default VPC, run `aws ec2 create-default-vpc --region <region>`.

## Upgrading from v3 to v4

- Requires AWS provider `>= 6.0` and Terraform `>= 1.5`.
- **GuardDuty findings export is now opt-in.** The module no longer discovers the detector (which failed in regions without one). Pass `guardduty_detector_id` to keep exporting findings; without it, the existing publishing destination is destroyed. The plan fails if the detector id does not exist in the region.
- **EBS encryption by default is controlled by `enable_ebs_encryption_by_default`** (default `true`) instead of the current account state. v3 destroyed this resource on the apply after enabling it, which disabled default encryption. Expect it to be created on first v4 apply.
- `password_history` default changed from 8 to 24 (CIS). Set it explicitly to keep the old value. `max_password_age = 0` now means passwords never expire.
- The IAM password policy moves to `aws_iam_account_password_policy.policy[0]`; a `moved` block handles this automatically.
- The GuardDuty bucket and KMS key policies now restrict GuardDuty access with `aws:SourceAccount`/`aws:SourceArn` and require uploads to use the security KMS key. Both policies update in place.
- The findings bucket enables S3 bucket keys to reduce KMS request costs.
- The `ebs_encryption_by_default` output now reports the module setting rather than the pre-apply account state.
- New inputs: `manage_global_resources`, `enable_ebs_encryption_by_default`, `ebs_default_kms_key_arn`, `ebs_snapshot_block_public_access_state`, `guardduty_detector_id`, `guardduty_findings_retention_days`, `kms_alias_name`.
- New outputs: `kms_key_arn`, `kms_key_alias`, `guardduty_findings_bucket_name`, `guardduty_findings_bucket_arn`, `access_analyzer_arn`.

<!-- BEGIN_TF_DOCS -->


## Example

```hcl
module "security-baseline" {
  source                                 = "github.com/fortunecookiezen/aws-tf-account-security?ref=v4.0.0"
  account_alias                          = "my-account-alias"
  create_access_analyzer                 = true
  create_s3_public_access_block          = true
  ebs_snapshot_block_public_access       = true
  ebs_snapshot_block_public_access_state = "block-all-sharing"
  aws_ec2_image_block_public_access      = true
  guardduty_detector_id                  = "12abc34d567e8fa901bc2d34e56789f0"
  guardduty_findings_retention_days      = 365
  minimum_password_length                = 16
  password_history                       = 24
  vpc_internet_gateway_block_mode        = "off"
  vpc_block_public_access_exclusion = {
    "vpc-0f54aefb63f391295" = "allow-egress"
  }
}

# second region: regional controls only
module "security-baseline-us-west-2" {
  source                  = "github.com/fortunecookiezen/aws-tf-account-security?ref=v4.0.0"
  providers               = { aws = aws.us-west-2 }
  account_alias           = "my-account-alias"
  manage_global_resources = false
}
```

## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.68.0 |

## Modules

No modules.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_account_alias"></a> [account\_alias](#input\_account\_alias) | account metadata friendly name for the aws account, used as the access analyzer name | `string` | n/a | yes |
| <a name="input_aws_ec2_image_block_public_access"></a> [aws\_ec2\_image\_block\_public\_access](#input\_aws\_ec2\_image\_block\_public\_access) | block public access to ec2 images, defaults to true | `bool` | `true` | no |
| <a name="input_create_access_analyzer"></a> [create\_access\_analyzer](#input\_create\_access\_analyzer) | create iam access analyzer, defaults to true | `bool` | `true` | no |
| <a name="input_create_account_alias"></a> [create\_account\_alias](#input\_create\_account\_alias) | set the iam account alias to account\_alias. ignored when manage\_global\_resources is false | `bool` | `false` | no |
| <a name="input_create_s3_public_access_block"></a> [create\_s3\_public\_access\_block](#input\_create\_s3\_public\_access\_block) | create account-level s3 public access block, defaults to true, no longer really required since aws updated their default behavior. ignored when manage\_global\_resources is false | `bool` | `true` | no |
| <a name="input_create_unused_access_analyzer"></a> [create\_unused\_access\_analyzer](#input\_create\_unused\_access\_analyzer) | create an iam access analyzer for unused access. this is a paid feature billed per iam role and user analyzed. ignored when manage\_global\_resources is false | `bool` | `false` | no |
| <a name="input_ebs_default_kms_key_arn"></a> [ebs\_default\_kms\_key\_arn](#input\_ebs\_default\_kms\_key\_arn) | arn of a customer managed kms key to use for ebs encryption by default. defaults to null, which uses the aws managed aws/ebs key | `string` | `null` | no |
| <a name="input_ebs_snapshot_block_public_access"></a> [ebs\_snapshot\_block\_public\_access](#input\_ebs\_snapshot\_block\_public\_access) | block public sharing of ebs snapshots, defaults to true | `bool` | `true` | no |
| <a name="input_ebs_snapshot_block_public_access_state"></a> [ebs\_snapshot\_block\_public\_access\_state](#input\_ebs\_snapshot\_block\_public\_access\_state) | ebs snapshot block public access state, block-all-sharing or block-new-sharing | `string` | `"block-all-sharing"` | no |
| <a name="input_emr_block_public_access"></a> [emr\_block\_public\_access](#input\_emr\_block\_public\_access) | block emr clusters from launching with security groups that allow public inbound access, with no port exceptions | `bool` | `true` | no |
| <a name="input_enable_ebs_encryption_by_default"></a> [enable\_ebs\_encryption\_by\_default](#input\_enable\_ebs\_encryption\_by\_default) | enable ebs encryption by default in this region. setting this to false after it was true disables ebs encryption by default | `bool` | `true` | no |
| <a name="input_guardduty_detector_id"></a> [guardduty\_detector\_id](#input\_guardduty\_detector\_id) | id of the existing guardduty detector in this region. when set, findings are exported to the module's s3 bucket. the plan fails if the detector does not exist | `string` | `null` | no |
| <a name="input_guardduty_findings_retention_days"></a> [guardduty\_findings\_retention\_days](#input\_guardduty\_findings\_retention\_days) | days to retain guardduty findings (current and noncurrent versions) in the findings bucket. defaults to null, which retains findings indefinitely | `number` | `null` | no |
| <a name="input_imds_hop_limit"></a> [imds\_hop\_limit](#input\_imds\_hop\_limit) | imds put response hop limit default. 2 allows containers on ec2 to reach imdsv2 | `number` | `2` | no |
| <a name="input_kms_alias_name"></a> [kms\_alias\_name](#input\_kms\_alias\_name) | alias for the security kms key. kms aliases are regional, so this only needs changing if the module is deployed more than once in the same region | `string` | `"alias/security-key"` | no |
| <a name="input_manage_global_resources"></a> [manage\_global\_resources](#input\_manage\_global\_resources) | manage account-global resources (iam password policy, account-level s3 public access block). set to false on all but one instance when deploying this module to multiple regions | `bool` | `true` | no |
| <a name="input_max_password_age"></a> [max\_password\_age](#input\_max\_password\_age) | maximum password age in days. set to 0 for passwords that never expire, as recommended by NIST SP 800-63B | `number` | `90` | no |
| <a name="input_minimum_password_length"></a> [minimum\_password\_length](#input\_minimum\_password\_length) | minimum allowed length of password | `number` | `14` | no |
| <a name="input_password_history"></a> [password\_history](#input\_password\_history) | number of previous passwords retained in history to prevent reuse of passwords, CIS recommends 24 | `number` | `24` | no |
| <a name="input_require_imdsv2"></a> [require\_imdsv2](#input\_require\_imdsv2) | require imdsv2 for new ec2 instances in this region that don't set their own metadata options | `bool` | `true` | no |
| <a name="input_restrict_default_security_group"></a> [restrict\_default\_security\_group](#input\_restrict\_default\_security\_group) | remove all ingress and egress rules from the default vpc's default security group. no-op when there is no default vpc | `bool` | `true` | no |
| <a name="input_security_contact"></a> [security\_contact](#input\_security\_contact) | security alternate contact for the account. defaults to null, which leaves the contact unmanaged, e.g. when it is set from the organization management account. ignored when manage\_global\_resources is false | <pre>object({<br/>    name          = string<br/>    title         = string<br/>    email_address = string<br/>    phone_number  = string<br/>  })</pre> | `null` | no |
| <a name="input_ssm_block_public_document_sharing"></a> [ssm\_block\_public\_document\_sharing](#input\_ssm\_block\_public\_document\_sharing) | block public sharing of ssm documents in this region | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_unused_access_age_days"></a> [unused\_access\_age\_days](#input\_unused\_access\_age\_days) | days without use before the unused access analyzer reports a permission, role, or credential as unused | `number` | `90` | no |
| <a name="input_vpc_block_public_access_exclusion"></a> [vpc\_block\_public\_access\_exclusion](#input\_vpc\_block\_public\_access\_exclusion) | map of vpc ids to block public access exclusion mode, e.g. { "vpc-12345678" = "allow-bidirectional" } | `map(string)` | `{}` | no |
| <a name="input_vpc_internet_gateway_block_mode"></a> [vpc\_internet\_gateway\_block\_mode](#input\_vpc\_internet\_gateway\_block\_mode) | vpc internet gateway block mode, can be block-bidirectional, block-ingress, or off | `string` | `"block-bidirectional"` | no |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_accessanalyzer_analyzer.analyzer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/accessanalyzer_analyzer) | resource |
| [aws_accessanalyzer_analyzer.unused_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/accessanalyzer_analyzer) | resource |
| [aws_account_alternate_contact.security](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/account_alternate_contact) | resource |
| [aws_default_security_group.default_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_ebs_default_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_default_kms_key) | resource |
| [aws_ebs_encryption_by_default.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_encryption_by_default) | resource |
| [aws_ebs_snapshot_block_public_access.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_snapshot_block_public_access) | resource |
| [aws_ec2_image_block_public_access.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_image_block_public_access) | resource |
| [aws_ec2_instance_metadata_defaults.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ec2_instance_metadata_defaults) | resource |
| [aws_emr_block_public_access_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/emr_block_public_access_configuration) | resource |
| [aws_guardduty_publishing_destination.account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/guardduty_publishing_destination) | resource |
| [aws_iam_account_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_account_alias) | resource |
| [aws_iam_account_password_policy.policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_account_password_policy) | resource |
| [aws_kms_alias.security_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.security](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_s3_account_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_account_public_access_block) | resource |
| [aws_s3_bucket.guardduty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.guardduty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.guardduty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.guardduty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.guardduty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.guardduty](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_ssm_service_setting.document_public_sharing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_service_setting) | resource |
| [aws_vpc_block_public_access_exclusion.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_block_public_access_exclusion) | resource |
| [aws_vpc_block_public_access_options.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_block_public_access_options) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_guardduty_detector.account](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/guardduty_detector) | data source |
| [aws_iam_policy_document.bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.key_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_vpcs.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpcs) | data source |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_access_analyzer_arn"></a> [access\_analyzer\_arn](#output\_access\_analyzer\_arn) | arn of the access analyzer, null when not created |
| <a name="output_ebs_encryption_by_default"></a> [ebs\_encryption\_by\_default](#output\_ebs\_encryption\_by\_default) | whether this module enables ebs encryption by default in this region |
| <a name="output_guardduty_findings_bucket_arn"></a> [guardduty\_findings\_bucket\_arn](#output\_guardduty\_findings\_bucket\_arn) | arn of the guardduty findings bucket |
| <a name="output_guardduty_findings_bucket_name"></a> [guardduty\_findings\_bucket\_name](#output\_guardduty\_findings\_bucket\_name) | name of the guardduty findings bucket |
| <a name="output_kms_key_alias"></a> [kms\_key\_alias](#output\_kms\_key\_alias) | alias of the security kms key |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | arn of the security kms key |
| <a name="output_unused_access_analyzer_arn"></a> [unused\_access\_analyzer\_arn](#output\_unused\_access\_analyzer\_arn) | arn of the unused access analyzer, null when not created |
<!-- END_TF_DOCS -->
