# Publics
resource "aws_subnet" "public" {
  for_each = { for idx, az in var.azs : idx => { az = az, cidr = local.public_subnets[idx] } }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name}-public-${each.value.az}"
    Tier = "public"
  })
}

# Privates
resource "aws_subnet" "private" {
  for_each = { for idx, az in var.azs : idx => { az = az, cidr = local.private_subnets[idx] } }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(local.common_tags, {
    Name = "${local.name}-private-${each.value.az}"
    Tier = "private"
  })
}
