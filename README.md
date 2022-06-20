## Autoscaling with Launch Configuration using Terraform
### Exp-01: Overview
In this branch we are going to implement 3-tier app architecture via autoscaling which will map it with ALB. This branch based on `v2-ALB-Application-LoadBalancer-Basic`

Here will include these major module as below:

- Autoscaling Module
  - Autoscaling Notification
  - Target Tracking Scaling Policy
  - Schedule action
  - Launch Configuration
- Application load balancer

### Exp-02: major terraform configuration files

#### Exp-02-01: exp-3-local-values.tf
```t
  asg_tags = [
    {
      key                 = "Project"
      value               = "ASG"
      propagate_at_launch = true
    },
    {
      key                 = "foo"
      value               = ""
      propagate_at_launch = true
    },
  ]
```

#### Exp-02-02: exp-7-02-ec2instance-outputs.tf 
- Only outputs for Bastion EC2 Instance is present
```t
# ec2_bastion_public_instance_ids
output "ec2_bastion_public_instance_ids" {
  description = "List of IDs of instances"
  value       = module.ec2_public.id
}

# ec2_bastion_public_ip
output "ec2_bastion_public_ip" {
  description = "List of public IP addresses assigned to the instances"
  value       = module.ec2_public.public_ip 
}
```

#### Exp-02-03: exp-10-02-ALB-application-loadbalancer.tf
- **Change-1:** For `subnets` argument, either we can give specific subnets or we can also give all private subnets defined. 
- **Change-2:**
  - In ASG, we will be referencing the load balancer `target_group_arns= module.alb.target_group_arns` 
  - Define target group to app1 and relevant rule
- **Change-3:** changed the path patter as `path_patterns = ["/app*"]`
```t
# Terraform AWS Application Load Balancer (ALB)
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "6.0.0" 

  name = "${local.name}-alb"
  load_balancer_type = "application"
  vpc_id = module.vpc.vpc_id
  subnets = module.vpc.public_subnets
  security_groups = [module.loadbalancer_sg.security_group_id]
  # Listeners
  # HTTP Listener - HTTP to HTTPS Redirect
    http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      action_type = "redirect"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  ]  
  # Target Groups
  target_groups = [
    # App1 Target Group - TG Index = 0
    {
      name_prefix          = "app1-"
      backend_protocol     = "HTTP"
      backend_port         = 80
      target_type          = "instance"
      deregistration_delay = 10
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/app1/index.html"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }
      protocol_version = "HTTP1"
    },  
  ]

  # HTTPS Listener
  https_listeners = [
    # HTTPS Listener Index = 0 for HTTPS 443
    {
      port               = 443
      protocol           = "HTTPS"
      certificate_arn    = module.acm.acm_certificate_arn
      action_type = "fixed-response"
      fixed_response = {
        content_type = "text/plain"
        message_body = "Fixed Static message - for Root Context"
        status_code  = "200"
      }
    }, 
  ]

  # HTTPS Listener Rules
  https_listener_rules = [
    # Rule-1: /app1* should go to App1 EC2 Instances
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
        path_patterns = ["/app*"]
      }]
    },  
  ]
  tags = local.common_tags
}
```

#### Exp-02-04: exp-12-route53-dnsregistration.tf
- Update the DNS name relevant to demo
```t
  name    = "asg-lc.galaxy-aws.top"
```

#### Exp-02-05: Autoscaling with Launch Configuration
##### Exp-02-05-01: exp-13-02-autoscaling-additional-resoures.tf
```t
# AWS IAM Service Linked Role for Autoscaling Group
resource "aws_iam_service_linked_role" "autoscaling" {
  aws_service_name = "autoscaling.amazonaws.com"
  description      = "A service linked role for autoscaling"
  custom_suffix    = local.name

  # Sometimes good sleep is required
  provisioner "local-exec" {
    command = "sleep 10"
  }
}

# Output AWS IAM Service Linked Role
output "service_linked_role_arn" {
    value   = aws_iam_service_linked_role.autoscaling.arn
}
```

##### Exp-02-05-02: exp-13-03-autoscaling-with-launchconfiguration.tf
```t
# Autoscaling with Launch Configuration - Both created at a time
module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "4.1.0"

  # Autoscaling group
  name            = "${local.name}-myasg1"
  use_name_prefix = false

  min_size                  = 2
  max_size                  = 10
  desired_capacity          = 2
  #desired_capacity          = 3  # Changed for testing Instance Refresh
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"
  vpc_zone_identifier       = module.vpc.private_subnets
  service_linked_role_arn   = aws_iam_service_linked_role.autoscaling.arn
  # Associate ALB with ASG
  target_group_arns         = module.alb.target_group_arns

  # ASG Lifecycle Hooks
  initial_lifecycle_hooks = [
    {
      name                 = "ExampleStartupLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 60
      lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "hello" = "world" })
    },
    {
      name                 = "ExampleTerminationLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 180
      lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "goodbye" = "world" })
    }
  ]

  # ASG Instance Referesh
  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      min_healthy_percentage = 50
    }
    triggers = ["tag", "desired_capacity", "max_size"]
  }

  # ASG Launch configuration
  lc_name   = "${local.name}-myLaunchConfiguration1"
  use_lc    = true
  create_lc = true

  image_id          = data.aws_ami.amzlinux2.id
  instance_type     = var.instance_type
  key_name          = var.instance_keypair
  user_data         = file("${path.module}/app1-install.sh")
  ebs_optimized     = true
  enable_monitoring = true

  security_groups             = [module.private_sg.security_group_id]
  associate_public_ip_address = false

  # Add Spot Instances (Optional argument)
  spot_price        = "0.014"
  #spot_price        = "0.016" # Change for Instance Refresh test

  ebs_block_device = [
    {
      device_name           = "/dev/xvdz"
      delete_on_termination = true
      encrypted             = true
      volume_type           = "gp2"
      volume_size           = "20"
    },
  ]

  root_block_device = [
    {
      delete_on_termination = true
      encrypted             = true
      volume_size           = "15"
      volume_type           = "gp2"
    },
  ]

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "optional" # At production grade you can change to "required"
  }

  tags        = local.asg_tags 
}
```

##### Exp-02-05-03: exp-13-05-autoscaling-notifications.tf

```t
# Autoscaling Notifications
# Due to that create SNS Topic with unique name 

# SNS - Topic
resource "aws_sns_topic" "myasg_sns_topic" {
  name = "myasg-sns-topic-${random_pet.this.id}"
}

# SNS - Subscription
resource "aws_sns_topic_subscription" "myasg_sns_topic_subscription" {
  topic_arn = aws_sns_topic.myasg_sns_topic.arn
  protocol  = "email"
  endpoint  = "bingo4933@gmail.com"
}
## Create Autoscaling Notification Resource
resource "aws_autoscaling_notification" "myasg_notifications" {
  group_names = [module.autoscaling.autoscaling_group_id]
  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]
  topic_arn = aws_sns_topic.myasg_sns_topic.arn 
}
```

##### Exp-02-05-04-main.tf

- need a resource of random

```t
# Create Random Pet Resource
resource "random_pet" "this" {
  length = 2
}
```

##### Exp-02-05-05: exp-13-05-autoscaling-notifications.tf
```t
# Autoscaling Notifications
## SNS - Topic
resource "aws_sns_topic" "myasg_sns_topic" {
  name = "myasg-sns-topic-${random_pet.this.id}"
}

## SNS - Subscription
resource "aws_sns_topic_subscription" "myasg_sns_topic_subscription" {
  topic_arn = aws_sns_topic.myasg_sns_topic.arn
  protocol  = "email"
  endpoint  = "stacksimplify@gmail.com"
}

## Create Autoscaling Notification Resource
resource "aws_autoscaling_notification" "myasg_notifications" {
  group_names = [module.autoscaling.autoscaling_group_id]
  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]
  topic_arn = aws_sns_topic.myasg_sns_topic.arn 
}
```

##### Exp-02-05-06: exp-13-06-autoscaling-ttsp.tf
```t
###### Target Tracking Scaling Policies ######
# TTS - Scaling Policy-1: Based on CPU Utilization of EC2 Instances
# Define Autoscaling Policies and Associate them to Autoscaling Group
resource "aws_autoscaling_policy" "avg_cpu_policy_greater_than_xx" {
  name                   = "avg-cpu-policy-greater-than-xx"
  # Important Note: The policy type, either "SimpleScaling", "StepScaling" or "TargetTrackingScaling". If this value isn't provided, AWS will default to "SimpleScaling."
  policy_type = "TargetTrackingScaling"    
  autoscaling_group_name = module.autoscaling.autoscaling_group_id
  # defaults to ASG default cooldown 300 seconds if not set
  estimated_instance_warmup = 180
  # CPU Utilization is above 50
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 50.0
  }  
 
}

# TTS - Scaling Policy-2: Based on ALB Target Requests
resource "aws_autoscaling_policy" "alb_target_requests_greater_than_yy" {
  name                   = "alb-target-requests-greater-than-yy"
  policy_type = "TargetTrackingScaling"    
  autoscaling_group_name = module.autoscaling.autoscaling_group_id
  estimated_instance_warmup = 120  
  # Number of requests > 10 completed per target in an Application Load Balancer target group.
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label =  "${module.alb.lb_arn_suffix}/${module.alb.target_group_arn_suffixes[0]}"    
    }  
    target_value = 10.0
  }    
}
```

##### Exp-02-05-07: ASG Scheduled Actions
- `start_time` is given as future date for demo in this case, you can correct that based on your need.
- Time in `start_time` should be in UTC Timezone so please convert from your local time to UTC Time accordingly. 
- [UTC Timezone converter](https://www.worldtimebuddy.com/)

```t
## Create Scheduled Actions
## Create Scheduled Action-1: Increase capacity during business hours
resource "aws_autoscaling_schedule" "increase_capacity_9am" {
  scheduled_action_name  = "increase-capacity-9am"
  min_size               = 2
  max_size               = 10
  desired_capacity       = 8
  # Note: UTC time format, set year value 2030 for demo 
  start_time             = "2030-12-11T09:00:00Z"
  recurrence             = "00 09 * * *"
  autoscaling_group_name = module.autoscaling.autoscaling_group_id 
}

## Create Scheduled Action-2: Decrease capacity during non-business hours
resource "aws_autoscaling_schedule" "decrease_capacity_9pm" {
  scheduled_action_name  = "decrease-capacity-9pm"
  min_size               = 2
  max_size               = 10
  desired_capacity       = 2
  start_time             = "2030-12-11T21:00:00Z"
  recurrence             = "00 21 * * *"
  autoscaling_group_name = module.autoscaling.autoscaling_group_id 
}
```

### Exp-03: Execute Terraform Commands
```t
# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve
```

### Exp-04: Verify and test
```t
# Access and Test
http://asg-lc.galaxy-aws.top
http://asg-lc.galaxy-aws.top/app1/index.html
http://asg-lc.galaxy-aws.top/app1/metadata.html
```


#### Exp-04-01: Changes to ASG - Test Instance Refresh
- Change Desired capacity to 3 `desired_capacity = 3` and test
- Any change to ASG specific arguments listed in `triggers` of `instance_refresh` block, do a instance refresh
```t
  # ASG Instance Referesh
  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      min_healthy_percentage = 50
    }
    triggers = ["tag", "desired_capacity"]
  }
```
- Execute Terraform Commands
```t
# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# Observation
1. Consistently monitor the Autoscaling "Activity" and "Instance Refresh" tabs.
2. In close to 5 to 10 minutes, instances will be refreshed
3. Verify EC2 Instances, old will be terminated and new will be created
```

#### Exp-04-02: Change to Launch Configuration - Test Instance Refresh
- In this case, we change `spot_price` for refresh to Instance 
```t
# Before
  spot_price        = "0.014"
# After
  spot_price        = "0.015" # Change for Instance Refresh test
```
- Execute Terraform Commands
```t
# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# Observation
1. Consistently monitor the Autoscaling "Activity" and "Instance Refresh" tabs.
2. In close to 5 to 10 minutes, instances will be refreshed
3. Verify EC2 Instances, old will be terminated and new will be created
```
#### Exp-04-03: Test Autoscaling using Postman
- [Download Postman client and Install](https://www.postman.com/downloads/)
- Create New Collection: terraform-on-aws
- Create new Request: asg
- URL: https://asg-lc1.galaxy-aws.top/app1/metadata.html
- Click on **RUN**, with 5000 requests
- Monitor ASG -> Activity Tab
- Monitor EC2 -> Instances - To see if new EC2 Instances getting created (Autoscaling working as expected)
- It might take 5 to 10 minutes to autoscale with new EC2 Instances

### Exp-05: Clean-Up
```t
# Terraform Destroy
terraform destroy -auto-approve

# Clean-Up Files
rm -rf .terraform*
rm -rf terraform.tfstate*
```
