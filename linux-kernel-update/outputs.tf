output "instance_ids" {
  description = "Map of instance names to their IDs"
  value       = { for k, v in module.ec2-instance : k => v.id }
}

# output "instance_private_ips" {
#   description = "Map of instance names to their private IPs"
#   value       = { for k, v in module.ec2-instance : k => v.private_ip }
# }

# output "instance_public_ips" {
#   description = "Map of instance names to their public IPs"
#   value       = { for k, v in module.ec2-instance : k => v.public_ip }
# }

# output "instance_tags" {
#   description = "Map of instance names to their tags"
#   value       = { for k, v in module.ec2-instance : k => v.tags_all }
# }

# output "region" {
#   description = "The AWS region where resources are deployed"
#   value       = var.region
# }

# output "environment" {
#   description = "The environment name"
#   value       = var.environment
# }

output "ansible_inventory" {
  description = "Ansible inventory content in YAML format"
  value       = local.ansible_inventory_content
}

