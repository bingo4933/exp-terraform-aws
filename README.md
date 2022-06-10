## **AWS ALB Context Path based Routing using Terraform**

### **Exp-01: Introduction**

In this branch we will create Application Load Balancer based url path. This branch based on previous `v2-ALB-Application-LoadBalancer-Basic` 

Need to prepared the list below before implementing

- You need a Registered Domain in AWS Route53 or domain name vendor. In this case I’ve bought `galaxy-aws.top`
- Copy your `terraform-key.pem` file to `terraform-manifests/private-key` folder

### **Exp-02: Target**

- Our core focus in the entire section should be primarily targeted to two things
  - **Listener Indexes:** `https_listener_index = 0`
  - **Target Group Indexes:** `target_group_index = 0`
- I defined `http_tcp_listeners` which used to redirect `http` protocol to `https`
- I defined `https_listeners` which used to redirect traffic to fixed response page. It include a rule implicitly for that redirection action.
- I then, defined two `https_listener_rules` which point to `https_listeners`. As we only have one `https_listeners` defined in our case, the `index` should be `0`

- We are going to implement the following using AWS ALB

1. Fixed Response for /*: http://apps.galaxy-aws.top
2. App1/app1* goes to App1 EC2 Instances: http://apps.galaxy-aws.top/app1/index.html
3. App2/app2* goes to App2 EC2 Instance: http://apps.galaxy-aws.top/app2/index.html
4. HTTP to HTTPS Redirect

### **Exp-03: exp5-05-securitygroup-loadbalancersg.tf**

- allow port 443 for load balancer in this security group file

```t
ingress_rules = ["http-80-tcp", "https-443-tcp"]
```

### **Exp-04: exp6-02-datasource-route53-zone.tf**

- Define the datasource for [Route53 Zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone)

```t
# data source of route53_zone
# Get DNS information from AWS Route53
data "aws_route53_zone" "mydomain" {
  name = "galaxy-aws.top"
}

# Output MyDomain Zone ID
output "mydomain_zoneid" {
    value = "data.aws_route53_zone.mydomain.zone_id"
}

# Output MyDomain name
output "mydomain_name" {
    value = "data.aws_route53_zone.mydomain.name"
}
```

### **Exp-05: exp7-04-ec2instance-private-app1.tf**

As we need two APP running in respective zone, need `app1` and `app2` in different terraform files.

- We will change the module name from `ec2_private` to `ec2_private_app1`
- We will change the `name` to `${var.environment}-app1`

```t
# AWS EC2 Instance Terraform Module
module "ec2_private_app1" {
    depends_on = [ module.vpc ]
    source = "terraform-aws-modules/ec2-instance/aws"
    version = "2.17.0"

    name = "${var.environment}-app1"
    instance_count = "${var.private_instance_count}"

    ami = data.aws_ami.amzlinux2.id
    instance_type = "${var.instance_type}"
    key_name = "${var.instance_keypair}"

    #monitoring = true

    subnet_ids = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]]
    vpc_security_group_ids = [module.private_sg.this_security_group_id]
    user_data = file("${path.module}/app1-install.sh")
    tags = local.common_tags
}
```

### **Exp-06: exp7-05-ec2instance-private-app2.tf**

- Create new EC2 Instances for App2 Application
- **Module Name**: ec2_private_app2
- **Name:** `${var.environment}-app2`
- **User Data: ** `user_data=file("${path.module}/app2-install.sh`")

```t
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
    vpc_security_group_ids = [module.private_sg.this_security_group_id]
    user_data = file("${path.module}/app2-install.sh")
    tags = local.common_tags
}
```

### **Exp-07: exp11-acm-certificatemanager.tf**

- [Terraform AWS ACM Module](https://registry.terraform.io/modules/terraform-aws-modules/acm/aws/latest)

```t
# ACM Module - To create and verify SSL Certificates
module "acm" {
    source = "terraform-aws-modules/acm/aws"
    version = "2.14.0"

    domain_name = trimsuffix(data.aws_route53_zone.mydomain.name, ".")
    zone_id = data.aws_route53_zone.mydomain.zone_id

    subject_alternative_names = [
        "*.galaxy-aws.top"
    ]
    
    tags = local.common_tags
}

# Output ACM Certificate ARN
output "this_acm_certificate_arn" {
    value = module.acm.this_acm_certificate_arn
}
```

### **Exp-08: exp10-02-ALB-application-loadbalancer.tf**

- [Terraform ALB Module](https://registry.terraform.io/modules/terraform-aws-modules/alb/aws/latest)
- Our core manifest to achieve ALB

#### **Exp-08-01: HTTP to HTTPS Redirect**

```t
    http_tcp_listeners = [
        # HTTP redirect to HTTPS
        {
            port = 80
            protocol = "HTTP"
            action_type = "redirect"
            redirect = {
                port = "443"
                protocol = "HTTPS"
                status_code = "HTTP_301"
            }
        }
    ]
```

#### **Step-09-02: Add Target Group **

```t
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
                    target_id = module.ec2_private_app1.id[0]
                    port = 80
                },
                my_app1_vm2 = {
                    target_id = module.ec2_private_app1.id[1]
                    port = 80
                }
            }
            tags = local.common_tags
        },

        # app2 target group - TG Index = 1
        {
            name_prefix = "app2-"
            backend_protocol = "HTTP"
            backend_port = 80
            target_type = "instance"
            deregistration_delay = 10
            health_check = {
                enabled = true
                interval = true
                path = "/app2/index.html"
                port = "traffic-port"
                healthy_threshold = 3
                unhealthy_threshold = 3
                timeout = 6
                protocol = "HTTP"
                matcher = "200-399"
            }
            protocol_version = "HTTP1"
            # app2 target group - Targets
            targets = {
                my_app2_vm1 = {
                    target_id = module.ec2_private_app2.id[0]
                    port = 80
                },
                my_app2_vm2 = {
                    target_id = module.ec2_private_app2.id[1]
                    port = 80
                }
            }
            tags = local.common_tags
        }     
    ]
 
```

#### **Exp-09-03: Add HTTPS Listener**

1. Associate SSL Certificate ARN
2. Add fixed response for Root Context `/*`

```t
    # HTTPS Listener
    https_listeners = [
        {
            port = 443
            protocol = "HTTPS"
            certificate_arn = module.acm.this_acm_certificate_arn
            action_type = "fixed-response"
            fixed_response = {
                content_type = "text/plain"
                message_body = "Fixed Static message - for root context"
                status_code = "200"
            }
        }
    ]
```

#### **Exp-09-04: Add HTTPS Listener Rules**

- Create Rule-1: /app1* should go to App1 EC2 Instance
- Create Rule-2: /app2* should go to App2 EC2 Instances

```t
    # HTTPS Listener Rules
    https_listener_rules = [
        # rule-1: /app1* should go to app1 ec2 instance
        {
            https_listener_index = 0
            actions = [
                {
                    type = "forward"
                    target_group_index = 0
                }
            ]
            conditions = [{
                path_patterns = ["/app1*"]
            }]
        },
        # rule-2: /app2* should go to app2 ec2 instance
        {
            https_listener_index = 0
            actions = [
                {
                    type = "forward"
                    target_group_index = 1
                }
            ]
            conditions = [{
                path_patterns = ["/app2*"]
            }]
        },       
    ]

```

### **Exp-10: exp12-route53-dnsregistration.tf**

- [Route53 Record Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record)

```t
# registrate a domain name in Route53
# make an alias of domain name to ALB
resource "aws_route53_record" "apps_dns" {
    zone_id = data.aws_route53_zone.mydomain.zone_id
    name = "apps.galaxy-aws.top"
    type = "A"
    alias {
      name = module.alb.this_lb_dns_name
      zone_id = module.alb.this_lb_zone_id
      evaluate_target_health = true
    }
}
```

### **Exp-11: Execute Terraform commands**

```t
# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# Verify
# Test (Domain will be different for you based on your registered domain)
# Note: All the below URLS shoud redirect from HTTP to HTTPS
1. Fixed Response: http://apps.galaxy-aws.top   
2. App1 Landing Page: http://apps.galaxy-aws.top/app1/index.html
3. App1 Metadata Page: http://apps.galaxy-aws.top/app1/metadata.html
4. App2 Landing Page: http://apps.galaxy-aws.top/app2/index.html
5. App2 Metadata Page: http://apps.galaxy-aws.top/app2/metadata.html
```

### **Exp-12: Clean-Up**

```t
# Terraform Destroy
terraform destroy -auto-approve

# Delete files
rm -rf .terraform*
rm -rf terraform.tfstate*
```
