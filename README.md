## **AWS Application  Load Balancer with Terraform**

### **Exp-01: Introduction**

In this branch we will create application load balancer(ALB) based on previous core 3-Tier architecture in  branch `v1-classic-loadbalancer` 

This is basic application load balancer architecture, We will add more feature base on this in future branch.

We would utilized these components as below

- aws vpc module
- aws ec2 module
- aws security group module
- aws elasticIP resource
- nullresource-provisioner
- depends_on meta-argument
- application loadbalancer (*in This branch)
- varied type of variable definition

Relevant concept reference to

- [terraform-aws-modules/vpc/aws](https://gitee.com/link?target=https%3A%2F%2Fregistry.terraform.io%2Fmodules%2Fterraform-aws-modules%2Fvpc%2Faws%2Flatest)
- [terraform-aws-modules/security-group/aws](https://gitee.com/link?target=https%3A%2F%2Fregistry.terraform.io%2Fmodules%2Fterraform-aws-modules%2Fsecurity-group%2Faws%2Flatest)
- [terraform-aws-modules/ec2-instance/aws](https://gitee.com/link?target=https%3A%2F%2Fregistry.terraform.io%2Fmodules%2Fterraform-aws-modules%2Fec2-instance%2Faws%2Flatest)
- [Application Load Balancer terraform module](https://registry.terraform.io/modules/terraform-aws-modules/elb/aws/latest)

> Note: Note: need to prepared these staff before implementing
>
> - copy your AWS EC2 key pair `terraform-key.pem` in `private-key` folder
> - folder name to `local-exec-output-files` where `local-exec` provisioner will create file



### **Exp-02: Copy files from previous branch**

- Copy `terraform-manifests` folder from branch `v1-classic-loadbalancer`
- new created files as below
  - exp-10-01-ALB-application-loadbalancer-variables.tf
  - exp-10-02-ALB-application-loadbalancer.tf
  - exp-10-03-ALB-application-loadbalancer-outputs.tf

### **Exp-03: exp-10-02-ALB-application-loadbalancer.tf**

- exp-10-02-ALB-application-loadbalancer.tf

```t
# Terraform AWS Application Load Balancer(ALB)
module "alb" {
    source = "terraform-aws-modules/alb/aws"
    version = "5.16.0"

    name = "${local.name}-alb" 
    load_balancer_type = "application"
    
    # network
    vpc_id = module.vpc.vpc_id
    subnets = [
        module.vpc.public_subnets[0],
        module.vpc.public_subnets[1]
    ]
    security_groups = [module.loadbalancer_sg.this_security_group_id]
    
    http_tcp_listeners = [
        {
            port = 80
            protocol = "HTTP"
            target_group_index = 0
        }
    ]

    # Target Groups
    target_groups = [
        # app1 target group - TG Index = 0
        {
            name_prefix = "app1-"
            backend_protocol = "HTTP"
            backend_port = 80
            target_type = "instance"
            deregistration_delay = 10
            health_check = {
                enabled = true
                interval = true
                path = "/app1/index.html"
                port = "traffic-port"
                healthy_threshold = 3
                unhealthy_threshold = 3
                timeout = 6
                protocol = "HTTP"
                matcher = "200-399"
            }
            protocol_version = "HTTP1"
            # app1 target group - Targets
            targets = {
                my_app1_vm1 = {
                    target_id = module.ec2_private.id[0]
                    port = 80
                },
                my_app1_vm2 = {
                    target_id = module.ec2_private.id[1]
                    port = 80
                }
            }
            tags = local.common_tags
        }
    ]
    tags = local.common_tags
}
```

### **Exp-04: exp-10-03-ALB-application-loadbalancer-outputs.tf**

- exp-10-03-ALB-application-loadbalancer-outputs.tf

```t
# Terraform AWS Application Load Balancer(ALB) Outputs
output "this_lb_id" {
  description = "The ID and ARN of the load balancer we created."
  value       = module.alb.this_lb_id
}

output "this_lb_arn" {
  description = "The ID and ARN of the load balancer we created."
  value       = module.alb.this_lb_arn
}

output "this_lb_dns_name" {
  description = "The DNS name of the load balancer."
  value       = module.alb.this_lb_dns_name
}

output "this_lb_arn_suffix" {
  description = "ARN suffix of our load balancer - can be used with CloudWatch."
  value       = module.alb.this_lb_arn_suffix
}

output "this_lb_zone_id" {
  description = "The zone_id of the load balancer to assist with creating DNS records."
  value       = module.alb.this_lb_zone_id
}

output "http_tcp_listener_arns" {
  description = "The ARN of the TCP and HTTP load balancer listeners created."
  value       = module.alb.http_tcp_listener_arns
}

output "http_tcp_listener_ids" {
  description = "The IDs of the TCP and HTTP load balancer listeners created."
  value       = module.alb.http_tcp_listener_ids
}

output "https_listener_arns" {
  description = "The ARNs of the HTTPS load balancer listeners created."
  value       = module.alb.https_listener_arns
}

output "https_listener_ids" {
  description = "The IDs of the load balancer listeners created."
  value       = module.alb.https_listener_ids
}

output "target_group_arns" {
  description = "ARNs of the target groups. Useful for passing to your Auto Scaling group."
  value       = module.alb.target_group_arns
}

output "target_group_arn_suffixes" {
  description = "ARN suffixes of our target groups - can be used with CloudWatch."
  value       = module.alb.target_group_arn_suffixes
}

output "target_group_names" {
  description = "Name of the target group. Useful for passing to your CodeDeploy Deployment Group."
  value       = module.alb.target_group_names
}

output "target_group_attachments" {
  description = "ARNs of the target group attachment IDs."
  value       = module.alb.target_group_attachments
}
```

### **Exp-05: Execute Terraform Commands**

```t
$ terraform init

$ terraform validate

$ terraform plan

$ terraform apply -auto-approve

# Verify
Observation: Access sample app using Load Balancer DNS Name
# Example: from my environment
http://infra-dev-alb-1575108738.ap-northeast-1.elb.amazonaws.com 
http://infra-dev-alb-1575108738.ap-northeast-1.elb.amazonaws.com/app1/index.html
http://infra-dev-alb-1575108738.ap-northeast-1.elb.amazonaws.com/app1/metadata.html
```



### **Exp-06: Clean-Up**

```t
# Terraform Destroy
terraform destroy -auto-approve

# Delete files
rm -rf .terraform*
rm -rf terraform.tfstate*
```

