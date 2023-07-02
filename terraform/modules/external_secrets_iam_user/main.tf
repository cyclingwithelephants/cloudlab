
resource "aws_iam_user" "external_secrets" {
  name = "${var.env}_external_secrets"
  path = "/system/${var.env}"
}

resource "aws_iam_access_key" "external_secrets" {
  user = aws_iam_user.external_secrets.name
}

module "parameter_store_policy_document" {
  source  = "cloudposse/ssm-parameter-store-policy-documents/aws"
  version = "0.1.3"

  parameter_root_name = "/cloudlab/${var.env}/*"
  account_id          = var.aws_account_id
  region              = var.aws_region
}

resource "aws_iam_policy" "parameter_store_environmental_read_only" {
  name_prefix = "${var.env}_parameter_store_read_only"
  description = "Grants read access to all secrets stored under /cloudlab/${var.env}/*"
  path        = "/system/${var.env}"
  policy      = module.parameter_store_policy_document.read_parameter_store_policy
}

resource "aws_iam_user_policy_attachment" "machine_user_policy_attachment" {
  user       = aws_iam_user.external_secrets.name
  policy_arn = aws_iam_policy.parameter_store_environmental_read_only.arn
}
