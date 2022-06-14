## **AWS ALB Host Header using Terraform**

### **Pre-requisites**

- You need a Registered Domain. It’s `galaxy-aws.top` in this case.
- Copy your `terraform-key.pem` file to `terraform-manifests/private-key` folder

### **Step-01: Introduction**

- Implement AWS application load balancer based on host header based on previous branch `v3-ALB-Application-LoadBalancer-PathBasedRouting`
- Input `app1.galaxy-aws.top` domain name in browser should access to `app-1` page.
- Input `app2.galaxy-aws.top` should access to `app-2` page.
- Input `myapp.galaxy-aws.top` which don’t specify any particular name should go default page.

### **Step-02: main change/setting in .tf files**

- define two dns name variable in `exp-10-01-ALB-application-loadbalancer-variables.tf`

```t
# Terraform AWS Application Load Balancer Variables
variable "app1_dns_name" {
    description = "app1 DNS Name"
}

variable "app2_dns_name" {
    description = "app2 DNS Name"
}
```

- specify value of those variable in `loadbalancer.auto.tfvars`

```t
# for AWS load bakancer variables
app1_dns_name = "app1.galaxy-aws.top"
app2_dns_name = "app2.galaxy-aws.top"
```

- DNS register with terraform in `exp-12-route53-dnsregistration.tf`

```t
# registrate  domain name in Route53 respectively and make an alias of domain name to ALB
# define default domain name
resource "aws_route53_record" "default_dns" {
    zone_id = data.aws_route53_zone.mydomain.zone_id
    name = "myapp.galaxy-aws.top"
    type = "A"
    alias {
      name = module.alb.this_lb_dns_name
      zone_id = module.alb.this_lb_zone_id
      evaluate_target_health = true
    }
}

# app1 DNS
resource "aws_route53_record" "app1_dns" {
  zone_id = data.aws_route53_zone.mydomain.zone_id
  name = "${var.app1_dns_name}"
  type = "A"
  alias {
    name = module.alb.this_lb_dns_name
    zone_id = module.alb.this_lb_zone_id
    evaluate_target_health = true
  }
}

# app2 DNS
resource "aws_route53_record" "app1_dns" {
  zone_id = data.aws_route53_zone.mydomain.zone_id
  name = "${var.app2_dns_name}"
  type = "A"
  alias {
    name = module.alb.this_lb_dns_name
    zone_id = module.alb.this_lb_zone_id
    evaluate_target_health = true
  }
}
```

- ALB setting in file `exp-10-02-ALB-application-loadbalancer.tf`

  http protocol header redirect to https protocol and default page setting.

  ```t
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

  https listener rules, rule-1 to redirect traffic to app1 EC2 Instance

  ```t
      https_listener_rules = [
          # rule-1: app1.galaxy-aws.top should go to app1 ec2 instance
          {
              https_listener_index = 0
              actions = [
                  {
                      type = "forward"
                      target_group_index = 0
                  }
              ]
              conditions = [{
                  host_headers = ["${var.app1_dns_name}"]
              }]
  
  ```

  https listener rules, rule-2

  ```t
          {
              https_listener_index = 0
              actions = [
                  {
                      type = "forward"
                      target_group_index = 1
                  }
              ]
              conditions = [{
                  host_headers = ["${var.app2_dns_name}"]
              }]
          },
      ]
  ```

  

  ### **Step-03: Execute terraform command**

  ```t
  $ terraform init
  
  $ terraform validate
  
  $ terraform plan
  
  $ terraform apply -auto-approve
  # observation output
  1. verify EC2 Instance for app1
  2. verify EC2 Instance for app2
  3. verify security group for ALB
  4. verify ALB listener
  5. verify ALB target group
  6. verify SSL certificate
  7. verify DNS in Route53
  
  # default page
  Note: all below URL should redirect from HTTP to HTTPS
  1. fixed page return when specify http://myapp.galaxy-aws.top
  2. visit app1 with http://app1.galaxy-aws.top/app1/index.html
  3. check in  EC2 instance metadata with http://app1.galaxy-aws.top/app1/metadata.html
  
  4. visit app2 with http://app2.galaxy-aws.top/app2/index.html
  5. check in metadata http://app2.galaxy-aws.top/app2/metadata.html
  ```

  

  ### **Step-04: Clean-Up**

  ```t
  # Terraform Destroy
  terraform destroy -auto-approve
  
  # Delete files
  rm -rf .terraform*
  rm -rf terraform.tfstate*
  ```

  

  

