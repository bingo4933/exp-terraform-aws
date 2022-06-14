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