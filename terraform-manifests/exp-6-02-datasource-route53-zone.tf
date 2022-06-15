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