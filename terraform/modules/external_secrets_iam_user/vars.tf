variable "env" {
  type = string
}

variable "aws_region" {
  default = "eu-west-2"
  type    = string
}

variable "aws_account_id" {
  default = "the aws account ID of the parameter store you want to allow access to."
  type    = string
}
