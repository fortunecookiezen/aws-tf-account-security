module "security-baseline" {
  source                        = "github.com/fortunecookiezen/aws-tf-account-security"
  account_alias                 = "my-account-alias"
  create_access_analyzer        = true
  create_s3_public_access_block = true
}
