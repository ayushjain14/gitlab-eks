resource "aws_vpc" "devops" {
  cidr_block           = var.vpc_cidr_block
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Environment = "core"
    Name        = "devops"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_default_security_group" "defaul" {
    vpc_id = aws_vpc.devops.id
}
