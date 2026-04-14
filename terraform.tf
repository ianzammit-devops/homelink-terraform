terraform {
  # Store the state file in the remote state bucket
  backend "s3" {
    bucket       = "terraform-public-private-project"
    region       = "eu-west-2"
    use_lockfile = true
  }

  required_version = "~> 1.14.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}