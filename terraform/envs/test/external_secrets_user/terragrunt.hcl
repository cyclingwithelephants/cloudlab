# Automatically find the root terragrunt.hcl and inherit its configuration
include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/external_secrets_iam_user/"
}

inputs = {
  env = "dev"
  aws_account_id = "938128537395"
}
