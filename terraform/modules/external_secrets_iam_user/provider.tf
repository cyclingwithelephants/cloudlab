terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags = {
    env        = local.env
    managed_by = "terraform"
    repo       = "github.com/cyclingwithelephants/cloudlab"
  }
}
