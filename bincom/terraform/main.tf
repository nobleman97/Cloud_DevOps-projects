
locals {
  security_groups = {
    web   = aws_security_group.web.id
    mysql = aws_security_group.mysql.id

  }
}


resource "aws_key_pair" "bincom" {
  key_name   = "Bincom"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHVHQehfI4CzkOCtXQf8s563UHKRKhBoQAhc2N2Tn2eo root@be4107495dbf"
}


resource "aws_instance" "this" {
  for_each = var.vm
 
  associate_public_ip_address = var.vm[each.key].assign_ip
  vpc_security_group_ids = [local.security_groups[each.value.name]]
  subnet_id = aws_subnet.this[each.key].id
  ami           = "ami-0efcece6bed30fd98"
  instance_type = "t2.micro"
  key_name = aws_key_pair.bincom.id

  tags = {
    Name = "${each.value.name} Server"
  }
}


# resource "aws_nat_gateway" "pub" {
#   allocation_id = aws_eip.nat-ip.id
#   subnet_id     = aws_subnet.this["nat"].id

#   tags = {
#     Name = "gw NAT"
#   }

#   # To ensure proper ordering, it is recommended to add an explicit dependency
#   # on the Internet Gateway for the VPC.
#   depends_on = [aws_internet_gateway.gw]
# }

# resource "aws_eip" "nat-ip" {

#   domain   = "vpc"
# }