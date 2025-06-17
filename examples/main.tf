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
