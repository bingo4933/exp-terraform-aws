# AWS EC2 Instance Terraform Module
module "ec2_private_app2" {
    depends_on = [ module.vpc ]
    source = "terraform-aws-modules/ec2-instance/aws"
    version = "2.17.0"

    name = "${var.environment}-app2"
    instance_count = "${var.private_instance_count}"

    ami = data.aws_ami.amzlinux2.id
    instance_type = "${var.instance_type}"
    key_name = "${var.instance_keypair}"

    #monitoring = true

    subnet_ids = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]]
    vpc_security_group_ids = [module.private_sg.security_group_id]
    user_data = file("${path.module}/app2-install.sh")
    tags = local.common_tags
}