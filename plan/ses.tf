# resource "aws_ses_domain_identity" "gitlab" {
#   domain = "gitlab.${var.public_dns_name}"
# }

# resource "aws_route53_record" "example_amazonses_verification_record" {
#   zone_id = data.aws_route53_zone.public.zone_id
#   name    = "_amazonses.example.com"
#   type    = "TXT"
#   ttl     = "600"
#   records = [aws_ses_domain_identity.gitlab.verification_token]
# }
