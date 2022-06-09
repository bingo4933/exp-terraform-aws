# Create Elastic IP for Bastion Host
# Utilize Resource and depends_on
resource "aws_eip" "bastion_eip" {
    depends_on = [
      module.ec2_public,
      module.VPC
    ]
    instance = module.ec2_public.id[0]
    vpc = true
    tags = local.common_tags
}