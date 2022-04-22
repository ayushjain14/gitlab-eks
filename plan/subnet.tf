resource "aws_subnet" "private" {
  for_each = {
    for subnet in local.private_nested_config : subnet.name => subnet
  }

  vpc_id                  = aws_vpc.devops.id
  cidr_block              = each.value.cidr_block
  availability_zone       = var.az[index(local.private_nested_config, each.value)]
  map_public_ip_on_launch = false

  tags = {
    Environment                       = "devops"
    Name                              = each.value.name
    "kubernetes.io/role/internal-elb" = 1
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "aws_subnet" "public" {
  for_each = {
    for subnet in local.public_nested_config : subnet.name => subnet
  }

  vpc_id                  = aws_vpc.devops.id
  cidr_block              = each.value.cidr_block
  availability_zone       = var.az[index(local.public_nested_config, each.value)]
  map_public_ip_on_launch = true

  tags = {
    Environment              = "devops"
    Name                     = each.value.name
    "kubernetes.io/role/elb" = 1
  }

  lifecycle {
    ignore_changes = [tags]
  }
}
