## **AWS ALB  Custom Header and Query String **

### **Step-01: Introduction**

- We are going to implement ALB which support method of  custom header, query string and host header.
- you need a registered domain name before implementing

### **Step-02: main change**

- based on previous branch `v4-ALB-Application-LoadBalancer-HostHeaderBasedRouting`
- Define different HTTPS Listener Rules to achieve functionality

#### **Step-02-01: Rule-1: Custom Header Rule for App-1**

- in `exp-10-02-ALB-application-loadbalancer.tf`
- Rule-1: custom-header, if you specify particular header string like `myapp1` should go to App1 EC2 Instances
- setting priority with `1`

```t
    # Rule-1: custom-header=my-app-1 should go to App1 EC2 Instances
    { 
      https_listener_index = 0
      priority = 1      
      actions = [
        {
          type               = "forward"
          target_group_index = 0
        }
      ]
      conditions = [{ 
        http_headers = [{
          http_header_name = "custom-header"
          values           = ["app-1", "app1", "my-app-1", "myapp1", "myapp-1"]
        }]
      }]
    },
```

#### **Step-02-02:** Rule-2: Custom Header Rule for App-2

- in `exp-10-02-ALB-application-loadbalancer.tf`
- Rule-2: custom-header, if you specify particular header string like `myapp2` should go to App2 EC2 Instances
- setting priority with `1`

```t
    # Rule-2: custom-header=my-app-2 should go to App2 EC2 Instances    
    { 
      https_listener_index = 0
      priority = 2     
      actions = [
        {
          type               = "forward"
          target_group_index = 0
        }
      ]
      conditions = [{ 
        http_headers = [{
          http_header_name = "custom-header"
          values           = ["app-2", "app2", "my-app-2", "myapp2", "myapp-2"]
        }]
      }]
    },
```

#### **Step-02-03: Rule-3: Query String Redirect**

- Rule-3:  setting when query string of `q` equal to `terraform` redirect to [https://www.google.com/terraform](https://www.google.com/search?q=terraform)

```t
  Rule-3: Query String, q equal to terraform redirect to https://www.google.com
    { 
      https_listener_index = 0
      priority = 3
      actions = [{
        type        = "redirect"
        status_code = "HTTP_302"
        host        = "www.google.com"
        path        = "/search"
        query       = ""
        protocol    = "HTTPS"
      }]
      conditions = [{
        query_strings = [{
          key   = "q"
          value = "terraform"
          }]
      }]
    },
```

#### **Step-02-04: Rule-4: host header redirect

- Rule-4:  when setting host header to registered domain name  like module.galaxy-aws.top, redirect to [https://registry.terraform.io/browse/modules](https://registry.terraform.io/browse/modules)

```t
# Rule-4: custom host header, module.galaxy-aws.top, redirect to https://registry.terraform.io/browse/modules
    { 
      https_listener_index = 0
      priority = 4
      actions = [{
        type        = "redirect"
        status_code = "HTTP_302"
        host        = "registry.terraform.io"
        path        = "/browse/modules"
        query       = ""
        protocol    = "HTTPS"
      }]
      conditions = [{
        host_headers = ["module.galaxy-aws.top"]
      }]
    },  
```

#### **Step-03: exp-12-route53-dnsregistration.tf**

- like above setting, we also need to define corresponding domain name

```t
# DNS Registration 
# Default DNS
resource "aws_route53_record" "default_dns" {
  zone_id = data.aws_route53_zone.mydomain.zone_id 
  name    = "myapp.galaxy-aws.top"
  type    = "A"
  alias {
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
    evaluate_target_health = true
  }  
}

# Host Header - Redirect to External Site from ALB HTTPS Listener Rules
resource "aws_route53_record" "app1_dns" {
  zone_id = data.aws_route53_zone.mydomain.zone_id 
  name    = "module.galaxy-aws.top"
  type    = "A"
  alias {
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
    evaluate_target_health = true
  }  
}
```

### **Step-04: Terraform ALB Module v6.0.0 Changes**

- update module of ALB to version 6.0.0
- simplify prefix string `this_`

#### **Step-04-01: exp-10-02-ALB-application-loadbalancer.tf**

```t
# Before
  version = "5.16.0"

# After
  version = "6.0.0"
```

#### **Step-04-02: exp-10-03-ALB-application-loadbalancer-outputs.tf**

- remove all `this_` in file

```t
output "lb_id" {
  description = "The ID and ARN of the load balancer we created."
  value       = module.alb.lb_id
}

output "lb_arn" {
  description = "The ID and ARN of the load balancer we created."
  value       = module.alb.lb_arn
}

output "lb_dns_name" {
  description = "The DNS name of the load balancer."
  value       = module.alb.lb_dns_name
}

output "lb_arn_suffix" {
  description = "ARN suffix of our load balancer - can be used with CloudWatch."
  value       = module.alb.lb_arn_suffix
}

output "lb_zone_id" {
  description = "The zone_id of the load balancer to assist with creating DNS records."
  value       = module.alb.lb_zone_id
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

#### **Step-04-03: exp-12-route53-dnsregistration.tf**

- modify relevant setting which associate old usecase
- remove `this_`

```t
# Before
    name                   = module.alb.this_lb_dns_name
    zone_id                = module.alb.this_lb_zone_id

# After
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id 
```

### **Step-05:** Execute Terraform Commands

```t
# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terrform Apply
terraform apply -auto-approve
```

### **Step-06: Verify HTTP Header Based Routing (Rule-1 and Rule-2**)**

- go to [https://restninja.io](https://gitee.com/link?target=https%3A%2F%2Frestninja.io%2F) for test

```t
# Verify Rule-1 and Rule-2
https://myapp.galaxy-aws.top
custom header = myapp1  - Should get the page from App1 
custom header = myapp2  - Should get the page from App2
```

### **Step-07: Verify Rule-3**

- test query string, q=terraform redirect to [https://www.google.com/terraform](https://www.google.com/search?q=terraform)

```t
# Verify Rule-3
https://myapp.galaxy-aws.top/?q=terraform
Observation: 
1. Should Redirect to https://www.google.com/search?q=terraform
```

### **Step-08: Verify Rule-4**

- test host header  module.galaxy-aws.top, redirect to [https://registry.terraform.io/browse/modules/](https://registry.terraform.io/browse/modules)

```t
# Verify Rule-4
http://module.galaxy-aws.top
Observation: 
1. Should redirect to https://registry.terraform.io/browse/modules
```

### **Step-09: Clean-Up**

```t
# Destroy Resources
terraform destroy -auto-approve

# Delete Files
rm -rf .terraform*
rm -rf terraform.tfstate
```
