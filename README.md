## **AWS Classic Load Balancer with Terraform**

### **Exp-01: Introduction**

In this branch we will create classic load balancer based on previous core 3-Tier architecture in  branch `v0-core-3tier-ec2instance-securitygroup` 

We would utilize these components as below

- aws vpc module
- aws ec2 module
- aws security group module
- aws elasticIP resource
- nullresource-provisioner
- depends_on meta-argument
- classic loadbalancer (*in This branch)
- varied type of variable definition

Relevant concept reference to

- [terraform-aws-modules/vpc/aws](https://gitee.com/link?target=https%3A%2F%2Fregistry.terraform.io%2Fmodules%2Fterraform-aws-modules%2Fvpc%2Faws%2Flatest)
- [terraform-aws-modules/security-group/aws](https://gitee.com/link?target=https%3A%2F%2Fregistry.terraform.io%2Fmodules%2Fterraform-aws-modules%2Fsecurity-group%2Faws%2Flatest)
- [terraform-aws-modules/ec2-instance/aws](https://gitee.com/link?target=https%3A%2F%2Fregistry.terraform.io%2Fmodules%2Fterraform-aws-modules%2Fec2-instance%2Faws%2Flatest)
- [terraform module AWS ELB](https://registry.terraform.io/modules/terraform-aws-modules/elb/aws/latest)

> Note: Note: need to prepared these staff before implementing
>
> - copy your AWS EC2 key pair `terraform-key.pem` in `private-key` folder
> - folder name to `local-exec-output-files` where `local-exec` provisioner will create file



### **Exp02: Copy core 3-Tier files from previous branch**

- Copy `terraform-manifests` folder from `v0-core-3tier-ec2instance-securitygroup`
- We will add five more files in addition to previous branch
  - exp-5-05-securitygroup-loadbalancersg.tf
  - exp-10-01-ELB-classic-loadbalancer-variables.tf
  - exp-10-02-ELB-classic-loadbalancer.tf
  - exp-10-03-ELB-classic-loadbalancer-outputs.tf


###  **Exp-03: exp-5-05-securitygroup-loadbalancersg.tf**

```t
# terraform AWS Classic Load Balancer security group
module "loadbalancer_sg" {
    source = "terraform-aws-modules/security-group/aws"
    version = "3.18.0"

    name = "loadbalancer-sg"
    description = "Security Group with HTTP open for entire VPC Block (IPv4 CIDR), egress ports are all world open"
    # VPC
    vpc_id = module.vpc.vpc_id
    # Ingress Rules & CIDR Blocks
    ingress_rules = ["http-80-tcp"]
    ingress_cidr_blocks = ["0.0.0.0/0"]
    ingress_with_cidr_blocks = [
        {
            from_port = 81
            to_port = 81
            protocol = 6
            description = "Allow Port 81 from internet"
            cidr_blocks = "0.0.0.0/0"
        },
    ]

    # Egress Rule - all-all open
    egress_rules = ["all-all"]
    # TAG
    tags = local.common_tags
}
```

### **Exp-04: AWS ELB Classic Load Balancer**

#### **Exp-04-01: exp-10-02-ELB-classic-loadbalancer.tf**

- [terraform-aws-modules/elb/aws](https://registry.terraform.io/modules/terraform-aws-modules/elb/aws/latest)

```t
# terraform AWS Classic Load Balancer(CLB)
module "elb" {
    source = "terraform-aws-modules/elb/aws"
    version = "2.5.0"

    name = "${local.name}-myelb"
    subnets = [module.vpc.public_subnets[0], module.vpc.public_subnets[1]]

    security_groups = [module.loadbalancer_sg.this_security_group_id]

    internal = false

    listener = [
        {
            instance_port = 80
            instance_protocol = "HTTP"
            lb_port = 80
            lb_protocol = "HTTP"
        },
        {
            instance_port = 80
            instance_protocol = "HTTP"
            lb_port = 81
            lb_protocol = "HTTP"
        },
    ]

    health_check = {
        target = "HTTP:80/"
        interval = 30
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 5
    }

    # ELB attachments
    number_of_instances = "${var.private_instance_count}"
    instances = [module.ec2_private.id[0], module.ec2_private.id[1]]

    # tag
    tags = local.common_tags
}
```

#### **Exp-04-02: Outputs for ELB Classic Load Balancer**

- exp-10-03-ELB-classic-loadbalancer-outputs.tf

```t
# Terraform AWS Classic Load Balancer (ELB-CLB) Outputs
output "this_elb_id" {
  description = "The name of the ELB"
  value       = module.elb.this_elb_id
}

output "this_elb_name" {
  description = "The name of the ELB"
  value       = module.elb.this_elb_name
}

output "this_elb_dns_name" {
  description = "The DNS name of the ELB"
  value       = module.elb.this_elb_dns_name
}

output "this_elb_instances" {
  description = "The list of instances in the ELB (if may be outdated, because instances are attached using elb_attachment resource)"
  value       = module.elb.this_elb_instances
}

output "this_elb_source_security_group_id" {
  description = "The ID of the security group that you can use as part of your inbound rules for your load balancer's back-end application instances"
  value       = module.elb.this_elb_source_security_group_id
}

output "this_elb_zone_id" {
  description = "The canonical hosted zone ID of the ELB (to be used in a Route 53 Alias record)"
  value       = module.elb.this_elb_zone_id
}
```

### **Exp-05: Execute Terraform Commands**

```t
$ terraform init

$ terraform validate

$ terraform plan

$ terraform apply -auto-approve

# will generate classic loadbalancer dns url like example
http://infra-dev-myelb-557211422.ap-northeast-1.elb.amazonaws.com
http://infra-dev-myelb-557211422.ap-northeast-1.elb.amazonaws.com:81

# copy these dns url in browser to test
http://infra-dev-myelb-557211422.ap-northeast-1.elb.amazonaws.com
http://infra-dev-myelb-557211422.ap-northeast-1.elb.amazonaws.com:81
http://infra-d-myelb-557211422.ap-northeast-1.elb.amazonaws.com:81/app1/metadata.html
```



### **Exp-06: Clean-Up**

```t
# Terraform Destroy
terraform destroy -auto-approve

# Delete files
rm -rf .terraform*
rm -rf terraform.tfstate*
```

