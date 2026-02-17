terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.32.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  backend "s3" {
    bucket         = "devopsroyale-state-files-ccsji365i"
    key            = "linux-kernel-updates/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"

    encrypt = true
  }
}

provider "aws" {
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::199174511003:role/terraform"
  }

}
