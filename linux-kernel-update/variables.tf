variable "environment" {
  type        = string
  description = "The environment name."
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

# EC2 Instances Configuration
variable "instances" {
  description = "Map of EC2 instances to create"
  type = map(object({
    instance_type = string
    ami_id        = string
    tags          = optional(map(string))
  }))
}

variable "ansible_serial_batch_size" {
  description = "Number of instances to update in parallel during rolling updates"
  type        = number
  default     = 1
}

# Ansible execution control
variable "run_ansible" {
  description = "Whether to run Ansible playbook after infrastructure provisioning"
  type        = bool
  default     = false
}

variable "linux_kernel_version" {
  description = "Amazon Linux 2023 release version to upgrade to (e.g., 2023.9.20251208, 2023.10.20260202). Leave empty for latest available in current release."
  type        = string
  default     = ""
}

variable "ansible_check_only" {
  description = "Run Ansible in check-only mode (dry run)"
  type        = bool
  default     = false
}

# Advanced: Specific kernel package version (rarely used)
variable "ansible_kernel_package" {
  description = "ADVANCED: Specific kernel package version to install (e.g., 6.1.112-122.189.amzn2023). Use 'latest' to install latest from the specified linux_kernel_version release. Most users should leave this as 'latest'."
  type        = string
  default     = "latest"
}
