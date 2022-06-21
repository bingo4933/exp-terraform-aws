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