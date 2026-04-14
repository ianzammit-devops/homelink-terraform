# General
variable "environment" {
  description = "The environment to deploy into"
  type        = string
  default     = "dev"
}

# AWS
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-2"
}

# EC2
variable "ec2_instance_type" {
  description = "The instance type for the EC2 instance"
  type        = string
  default     = "t3.micro"
}

# Amazon Linux 2023 kernel-6.1
variable "ec2_ami" {
  description = "The AMI for the EC2 instance"
  type        = string
  default     = "ami-0f1b092c39d616d45"
}

variable "ec2_iam_instance_profile" {
  description = "IAM instance profile name (not the role ARN) attached to the web server for S3 etc."
  type        = string
  default     = "Homelink-EC2-Access"
}

variable "my_ip_address" {
  description = "My IP address"
  type        = string
  default     = "XX.XX.XX.XX/32"
}

# Network variables
variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnets" {
  description = "The subnets for the VPC"
  type        = map(string)
  default = {
    "public"                 = "10.0.1.0/24",
    "private_rds"            = "10.0.2.0/24",
    "private_rds_redundancy" = "10.0.3.0/24" # For redundancy, required by RDS
  }
}

# RDS
variable "db_name" {
  description = "The name of the database"
  type        = string
  default     = "homelink"
}

variable "db_secret_name" {
  description = "The name of the RDS secret"
  type        = string
  default     = "db-terraform"
}

variable "github_deploy_token_secret_name" {
  description = "Secrets Manager secret id for GitHub PAT (JSON: {\"token\":\"ghp_...\"})"
  type        = string
  default     = "HomeLink-Github-Deploy_token"
}