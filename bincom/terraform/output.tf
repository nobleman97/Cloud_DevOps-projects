output "web-ip-address" {
  value = aws_instance.this["web"].public_ip
}

