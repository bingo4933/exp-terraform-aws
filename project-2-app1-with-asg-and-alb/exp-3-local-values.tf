# Define Local Values in Terraform
locals {
  owners = var.business_division
  environment = var.environment
  name = "${local.owners}-${local.environment}"
  common_tags = {
    owners = local.owners
    environment = local.environment
  }

  asg_tags = [
    {
      key                 = "Project"
      value               = "Infra"
      propagate_at_launch = true
    },
    {
      key                 = "foo"
      value               = ""
      propagate_at_launch = true
    },
  ]

}