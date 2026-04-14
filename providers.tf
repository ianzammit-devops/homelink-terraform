provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "Public-Private-Project-Terraform-${var.environment}"
      Managed_By  = "Terraform"
    }
  }
}