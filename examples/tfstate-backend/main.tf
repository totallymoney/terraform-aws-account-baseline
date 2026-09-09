# Stage 1. Apply this with local state, then move its state into the bucket it
# creates.
#
#   terraform init
#   terraform apply
#   # add the backend block printed by `terraform output backend_config`
#   terraform init -migrate-state

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0.0, < 7.0.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Owner       = "platform"
      Environment = "shared"
    }
  }
}

module "state" {
  source = "../../modules/tfstate-backend"

  name        = "example"
  bucket_name = "example-terraform-state-change-me"
}

output "backend_config" {
  value = module.state.backend_config
}
