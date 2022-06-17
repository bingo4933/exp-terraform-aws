# Security Group for private Bastion Host
module "private_sg" {
    source = "terraform-aws-modules/security-group/aws"
    version = "4.0.0"

    name = "private-sg"
    description = "Security Group with HTTP & SSH port open for entire VPC Block (IPv4 CIDR), egress ports are all world open"

    # VPC
    vpc_id = module.vpc.vpc_id

    # Ingress Rules & CIDR Blocks
    ingress_rules = ["ssh-tcp", "http-80-tcp", "http-8080-tcp"]
    ingress_cidr_blocks = ["module.vpc.vpc_cidr_block"]

    # Egress Rule - all-all open
    egress_rules = ["all-all"]

    # TAG
    tags = local.common_tags
}