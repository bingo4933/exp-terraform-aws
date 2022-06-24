# Terraform Remote State Datasource
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
      bucket = "galaxy-1024-terraform-on-aws-for-ec2"
      key = "dev/project1-vpc/terraform.tfstate"
      region = "ap-northeast-1"
  }
}