data "aws_caller_identity" "current" {}

data "aws_route53_zone" "public" {
  name = "${var.public_dns_name}."
}