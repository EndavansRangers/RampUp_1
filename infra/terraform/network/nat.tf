# EIP(s) for NAT
resource "aws_eip" "nat" {
  count      = var.nat_per_az ? length(var.azs) : 1
  domain     = "vpc"
  tags       = merge(local.common_tags, { Name = "${local.name}-nat-eip-${count.index}" })
}

# NAT GW(s): 1 for each AZ or only one NAT
resource "aws_nat_gateway" "this" {
  count = var.nat_per_az ? length(var.azs) : 1

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = var.nat_per_az ? aws_subnet.public[count.index].id : aws_subnet.public[0].id

  tags = merge(local.common_tags, { Name = "${local.name}-nat-${count.index}" })

  depends_on = [aws_internet_gateway.igw]
}
