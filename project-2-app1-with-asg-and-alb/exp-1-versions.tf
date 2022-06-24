# Terraform Block
terraform {
  required_version = "~> 0.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
    null = {
      source = "hashicorp/null"
      version = "~> 3.0"
    }    
    random = {
      source = "hashicorp/random"
      version = "~> 3.0"
    }            
  }
  # Adding Backend as S3 for Remote State Storage
  backend "s3" {
    bucket = "galaxy-1024-terraform-on-aws-for-ec2"
    key    = "dev/project2-app1/terraform.tfstate"
    region = "ap-northeast-1" 

    # For State Locking
    dynamodb_table = "dev-project2-app1"    
  }
}

# Provider Block
provider "aws" {
  region  = var.aws_region
  profile = "default"
}
# Create Random Pet Resource
resource "random_pet" "this" {
  length = 2
}