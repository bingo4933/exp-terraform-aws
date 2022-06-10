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