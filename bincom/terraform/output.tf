output "web-ip-address" {
  value = aws_instance.this["web"].public_ip
}

output "db-ip-address" {
  value = aws_instance.this["mysql"].private_ip
}