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