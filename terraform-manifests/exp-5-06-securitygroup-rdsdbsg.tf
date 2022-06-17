# Security Group for AWS RDS DB
module "rdsdb_sg" {
    source = "terraform-aws-modules/security-group/aws"
    version = "4.0.0"

    name = "rdsdb-sg"
    description = "Access to MySQL DB for entire VPC CIDR Block"

    # VPC
    vpc_id = module.vpc.vpc_id

    # Ingress Rules & CIDR Blocks
    ingress_with_cidr_blocks = [
        {
            from_port = 3306
            to_port = 3306
            protocol = "tcp"
            description = "MySQL access from within VPC"
            cidr_blocks = module.vpc.vpc_cidr_block
        },
    ]

    # Egress Rule - all-all open
    egress_rules = ["all-all"]

    # TAG
    tags = local.common_tags
}