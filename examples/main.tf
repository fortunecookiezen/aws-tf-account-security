module "security-baseline" {
  source                                 = "github.com/fortunecookiezen/aws-tf-account-security?ref=v4.1.0"
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
  source                  = "github.com/fortunecookiezen/aws-tf-account-security?ref=v4.1.0"
  providers               = { aws = aws.us-west-2 }
  account_alias           = "my-account-alias"
  manage_global_resources = false
}
