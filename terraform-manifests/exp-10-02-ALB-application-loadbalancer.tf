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
    
    # Listeners
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

    # HTTPS Listener
    # in our case, if we access http://myapp.galaxy-aws.top
    # it will redirect to https protocol to fixed response which is root context
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

    # HTTPS Listener Rules
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
        },
        # rule-2: app2.galaxy-aws.top should go to app2 ec2 instance
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

    # HTTPS Listener Rules
    tags = local.common_tags
}