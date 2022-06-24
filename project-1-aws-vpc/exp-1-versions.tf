# Terraform Block
terraform {
  required_version = "~> 0.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  # Adding Backend as S3 for Remote State Storage
  backend "s3" {
    bucket = "galaxy-1024-terraform-on-aws-for-ec2"
    key    = "dev/project1-vpc/terraform.tfstate"
    region = "ap-northeast-1" 
     
    # For State Locking
    dynamodb_table = "dev-project1-vpc"    
  }    
}

# Provider Block
provider "aws" {
  region  = var.aws_region
  profile = "default"
}