# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project demonstrates automated Linux kernel updates on Amazon Linux 2023 (AML2023) EC2 instances using Terraform for infrastructure provisioning and Ansible for configuration management.

## Infrastructure Components

### Terraform Architecture
- **VPC Module**: Creates network infrastructure with public/private subnets using the official `terraform-aws-modules/vpc/aws` module
- **EC2 Instance**: Amazon Linux 2023 instance with SSM enabled for remote management
- **Security Groups**: Controls traffic flow between EC2 instances and ALB
- **IAM**: EC2 instance profile with `AmazonSSMManagedInstanceCore` policy for Systems Manager access
- **State Management**: Remote state stored in S3 (`devopsroyale-state-files-ccsji365i`) with DynamoDB locking

### Key Configuration Details
- **Region**: us-east-1
- **AMI**: ami-0ca5a2f40c2601df6 (Amazon Linux 2023)
- **VPC CIDR**: 10.0.0.0/18
- **Availability Zones**: us-east-1a, us-east-1b
- **Instance Type**: t2.micro
- **Root Volume**: 20GB gp3, encrypted

## Terraform Commands

### Initialization and Planning
```bash
# Initialize Terraform (downloads providers and modules)
terraform init

# Format Terraform files
terraform fmt

# Validate configuration
terraform validate

# Generate execution plan
terraform plan

# Apply with auto-approve
terraform apply -auto-approve
```

### State Management
```bash
# Show current state
terraform show

# List resources in state
terraform state list

# Refresh state from real infrastructure
terraform refresh
```

### Destruction
```bash
# Destroy all resources
terraform destroy

# Destroy specific resource
terraform destroy -target=module.ec2-instance
```

## Ansible Configuration

The `ansible/` directory is designated for playbooks that perform kernel updates on the provisioned EC2 instances. Ansible will:
1. Check available kernel updates
2. Install kernel updates
3. Reboot the instance
4. Verify the new kernel is loaded

### Expected Ansible Structure
When implementing Ansible playbooks, they should be placed in the `ansible/` directory and should use AWS Systems Manager Session Manager or instance connect for connectivity rather than SSH keys.

## Environment Variables

Environment-specific configurations are managed through `.auto.tfvars` files:
- `dev.auto.tfvars`: Development environment configuration

## AWS Authentication

The provider assumes an IAM role (`arn:aws:iam::199174511003:role/terraform`) for operations. Ensure your AWS credentials are configured with permission to assume this role.

## Important Notes

- The EC2 instance uses IMDSv2 and is accessed via AWS Systems Manager Session Manager (no SSH keys required)
- NAT Gateway is disabled; instance uses public subnet with public IP for internet access
- Security group reference to `aws_security_group.alb_security_group` in main.tf:75 suggests ALB integration (resource not yet defined in codebase)
- The locals block in main.tf contains a commented `ansible_sleep_duration` variable that may be used for timing Ansible execution after infrastructure creation
