## AWS Network Load Balancer TCP and TLS with Terraform

### Exp-01: Overview

In this branch, we're going to implement Network load balancer based on branch `v8-ASG-AutoScalingGroup-with-LaunchTemplate`

This branch include module/resource as below

- Autoscaling Module
  - Autoscaling Notification
  - Target Tracking Scaling Policy
  - Schedule action
  - Launch Template
- Network load balancer

### Exp-02: major terraform configuration files

#### Exp-02-01: exp-5-04-securitygroup-privatesg.tf

- NLB requires private security group EC2 Instance to have the `ingress_cidr_blocks` as `0.0.0.0/0`

```t
# Before
  ingress_cidr_blocks = [module.vpc.vpc_cidr_block]

# After
  ingress_cidr_blocks = ["0.0.0.0/0"] # Required for NLB
```

#### Exp-02-02: exp-10-02-NLB-network-loadbalancer.tf

- Create [AWS Network Load Balancer using Terraform Module](https://registry.terraform.io/modules/terraform-aws-modules/alb/aws/latest)
- Create TCP Listener
- Create TLS Listener
- Create Target Group

```t
# Terraform AWS Network Load Balancer (NLB)
module "nlb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "6.0.0"
  name_prefix = "mynlb-"
  #name = "nlb-basic"
  load_balancer_type = "network"
  vpc_id = module.vpc.vpc_id
  subnets = module.vpc.public_subnets
  #security_groups = [module.loadbalancer_sg.this_security_group_id] # Security Groups not supported for NLB
  # TCP Listener 
    http_tcp_listeners = [
    {
      port               = 80
      protocol           = "TCP"
      target_group_index = 0
    }  
  ]  

  #  TLS Listener
  https_listeners = [
    {
      port               = 443
      protocol           = "TLS"
      certificate_arn    = module.acm.acm_certificate_arn
      target_group_index = 0
    },
  ]


  # Target Group
  target_groups = [
    {
      name_prefix      = "app1-"
      backend_protocol = "TCP"
      backend_port     = 80
      target_type      = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/app1/index.html"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
      }      
    },
  ]
  tags = local.common_tags 
}
```

#### Exp-02-03: exp-12-route53-dnsregistration.tf

- **Change-1**: Update DNS Name
- **Change-2:** Update `alias name`
- **Change-3:** Update `alias zone_id`

```t
# DNS Registration 
resource "aws_route53_record" "apps_dns" {
  zone_id = data.aws_route53_zone.mydomain.zone_id 
  name    = "nlb.galaxy-aws.top"
  type    = "A"
  alias {
    name                   = module.nlb.lb_dns_name
    zone_id                = module.nlb.lb_zone_id
    evaluate_target_health = true
  }  
}
```

#### Exp-02-04: exp-13-03-autoscaling-resource.tf

- Change the module name for `target_group_arns` to `nlb`

```t
# Before
  target_group_arns = module.alb.target_group_arns
# After
  target_group_arns = module.nlb.target_group_arns
```

#### Exp-02-05: exp-13-06-autoscaling-ttsp.tf

```t
###### Target Tracking Scaling Policies ######
# TTS - Scaling Policy-1: Based on CPU Utilization of EC2 Instances
# Define Autoscaling Policies and Associate them to Autoscaling Group
resource "aws_autoscaling_policy" "avg_cpu_policy_greater_than_xx" {
  name                   = "avg-cpu-policy-greater-than-xx"
  policy_type = "TargetTrackingScaling"    
  autoscaling_group_name = aws_autoscaling_group.my_asg.id
  estimated_instance_warmup = 120
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 10.0
  }
}
```

#### Exp-02-06: Execute Terraform Commands

```t
# Terraform Initialize
terraform init

# Terrafom Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve
```

### Exp-03: Verify the AWS resources created

```t
# Access and Test with Port 80 - TCP Listener
http://nlb.galaxy-aws.top
http://nlb.galaxy-aws.top/app1/index.html
http://nlb.galaxy-aws.top/app1/metadata.html

# Access and Test with Port 443 - TLS Listener
https://nlb.galaxy-aws.top
https://nlb.galaxy-aws.top/app1/index.html
https://nlb.galaxy-aws.top/app1/metadata.html
```

### Exp-04: Clean-Up

```t
# Terraform Destroy
terraform destroy -auto-approve

# Clean-Up Files
rm -rf .terraform*
rm -rf terraform.tfstate*
```
