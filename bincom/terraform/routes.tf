#  --------  Route Tables --------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  
  tags = { Name = "VPC public RT to IGW" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # route {
  #   cidr_block     = "0.0.0.0/0"
  #   nat_gateway_id =  aws_nat_gateway.pub.id
  # }


  tags = { Name = "VPC private RT to NAT" }
}


# ---------- RT Associations  ------------

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.this["web"].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {

  subnet_id      = aws_subnet.this["mysql"].id
  route_table_id = aws_route_table.private.id
}

# Associate NAT with a public subnet
resource "aws_route_table_association" "nat" {

  subnet_id      = aws_subnet.this["nat"].id
  route_table_id = aws_route_table.public.id
}