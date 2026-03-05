#AWS
terraform {
    required_version = "~>1.7"
    backend "s3" {
      bucket = "test"
      key = "test"
      region = "us-east-1"
      profile = "default"
      use_lockfile = true
    }
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 4.0"
        }
        random = {
            source  = "hashicorp/random"
            version = "~> 3.0"
        }
    }

}

provider "aws" {
    region = var.region
    default_tags {
        tags = {
            Env = "prod"
        }
    }
}
