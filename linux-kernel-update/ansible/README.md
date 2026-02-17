# Automated Linux Kernel Updates via AWS SSM

This directory contains Ansible playbooks and roles for automating Linux kernel updates on Amazon Linux 2023 EC2 instances using AWS Systems Manager (SSM) Session Manager connectivity. Ansible execution is integrated with Terraform for seamless infrastructure and configuration management.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Usage](#usage)
  - [Terraform-Driven Execution](#terraform-driven-execution)
  - [Standalone Ansible Execution](#standalone-ansible-execution)
  - [Verification Only](#verification-only)
- [Configuration](#configuration)
- [Reboot Process](#reboot-process)
- [Troubleshooting](#troubleshooting)
- [Architecture](#architecture)

---

## Overview

This automation provides:

- **SSM-based connectivity**: No SSH keys required, uses AWS Systems Manager
- **Terraform-driven execution**: Ansible runs automatically via Terraform null_resource
- **Rolling updates**: Update multiple instances safely (one at a time by default)
- **Pre-flight checks**: Validates system state before making changes
- **Post-update verification**: Confirms kernel packages were installed
- **Idempotent**: Safe to run multiple times
- **Manual reboot control**: Kernel updates installed without automatic reboot

**Key Features:**
- Support for specific kernel versions or latest available
- Configurable retry logic for DNF operations
- Check-only mode for dry runs
- Comprehensive logging and error handling
- Minimal blast radius with serial execution

**Important:** This automation installs kernel updates but does **NOT** automatically reboot instances. You must manually reboot to activate the new kernel.

---

## Prerequisites

### Local Machine Requirements

1. **AWS CLI v2**
   ```bash
   aws --version  # Should be 2.x or higher
   ```

2. **AWS Session Manager Plugin**
   ```bash
   session-manager-plugin  # Should execute without error
   ```

3. **Ansible >= 2.14**
   ```bash
   ansible --version  # Should be 2.14 or higher
   ```

4. **Python >= 3.8**
   ```bash
   python3 --version  # Should be 3.8 or higher
   ```

5. **Python packages: boto3, botocore**
   ```bash
   pip3 list | grep -E "boto3|botocore"
   ```

6. **Terraform >= 1.0**
   ```bash
   terraform --version
   ```

### AWS Requirements

1. **IAM Permissions**: Your AWS credentials must allow:
   - `ssm:StartSession` on target EC2 instances
   - `ssm:DescribeInstanceInformation`

2. **EC2 Instance Requirements**:
   - Amazon Linux 2023
   - SSM agent installed and running (included in AL2023 by default)
   - IAM instance profile with `AmazonSSMManagedInstanceCore` policy
   - Network connectivity to SSM endpoints (HTTPS/443)

---

## Installation

### 1. Install Session Manager Plugin

**Ubuntu/Debian:**
```bash
curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
sudo dpkg -i session-manager-plugin.deb
```

**macOS:**
```bash
brew install --cask session-manager-plugin
```

**Verify installation:**
```bash
session-manager-plugin
```

### 2. Install Python Dependencies

```bash
pip3 install boto3 botocore ansible
```

### 3. Configure AWS Credentials

Ensure AWS credentials are configured:
```bash
aws configure
# OR
export AWS_PROFILE=your-profile-name
```

---

## Quick Start

### Terraform-Driven Execution (Recommended)

From project root:

**Update to latest kernel:**
```bash
./run_kernel_update.sh
```

**Update to specific release version:**
```bash
./run_kernel_update.sh latest 2023.9.20251208
```

**Dry run (check-only mode):**
```bash
./run_kernel_update.sh latest "" true
```

**Reboot instance after update:**
```bash
aws ec2 reboot-instances --instance-ids $(terraform output -raw ec2_instance_id)
```

**Verify current kernel:**
```bash
./verify_kernel.sh
```

### Direct Terraform Execution

**Enable Ansible via Terraform variables:**

Create `ansible.auto.tfvars`:
```hcl
run_ansible              = true
ansible_kernel_version   = "latest"
ansible_release_version  = "2023.9.20251208"  # optional
ansible_check_only       = false
```

**Apply:**
```bash
terraform apply -var-file="dev.auto.tfvars"
```

---

## Usage

### Terraform-Driven Execution

The recommended approach is to use Terraform's `null_resource` to execute Ansible automatically:

#### Variables

Configure these variables in your `.tfvars` file or via CLI:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `run_ansible` | bool | `false` | Enable Ansible execution |
| `ansible_kernel_version` | string | `"latest"` | Kernel version to install |
| `ansible_release_version` | string | `""` | AL2023 release version |
| `ansible_check_only` | bool | `false` | Dry run mode |
| `ansible_serial_batch_size` | number | `1` | Rolling update batch size |

#### Examples

**Update to latest kernel:**
```bash
terraform apply \
  -var-file="dev.auto.tfvars" \
  -var="run_ansible=true" \
  -var="ansible_kernel_version=latest"
```

**Update to specific release:**
```bash
terraform apply \
  -var-file="dev.auto.tfvars" \
  -var="run_ansible=true" \
  -var="ansible_release_version=2023.9.20251208"
```

**Dry run:**
```bash
terraform apply \
  -var-file="dev.auto.tfvars" \
  -var="run_ansible=true" \
  -var="ansible_check_only=true"
```

### Standalone Ansible Execution

You can also run Ansible playbooks independently:

#### Update to Latest Kernel

```bash
cd ansible
ansible-playbook playbooks/kernel_update.yml -i inventory/hosts.yml
```

#### Update to Specific Release Version

```bash
ansible-playbook playbooks/kernel_update.yml \
  -i inventory/hosts.yml \
  -e "release_version=2023.9.20251208"
```

#### Check-Only Mode (Dry Run)

```bash
ansible-playbook playbooks/kernel_update.yml \
  -i inventory/hosts.yml \
  -e "kernel_update_check_only=true"
```

#### Update Multiple Instances (2 at a time)

```bash
ansible-playbook playbooks/kernel_update.yml \
  -i inventory/hosts.yml \
  -e "serial_batch_size=2"
```

### Verification Only

Run verification playbook to check current kernel status without making changes:

```bash
cd ansible
ansible-playbook playbooks/verify_kernel.yml -i inventory/hosts.yml
```

Or use the convenience script:
```bash
./verify_kernel.sh
```

---

## Configuration

### Inventory

The inventory file (`inventory/hosts.yml`) is auto-generated by Terraform. Example structure:

```yaml
all:
  children:
    kernel_update_targets:
      hosts:
        i-1234567890abcdef0:
          ansible_host: i-1234567890abcdef0
          ansible_connection: aws_ssm
          ansible_aws_ssm_region: us-east-1
          private_ip: 10.0.1.100
          environment: dev
```

### Group Variables

**`inventory/group_vars/all.yml`**: Global SSM connection settings
```yaml
ansible_connection: aws_ssm
ansible_aws_ssm_region: us-east-1
ansible_python_interpreter: /usr/bin/python3
ansible_become: true
```

**`inventory/group_vars/kernel_update_targets.yml`**: Target-specific settings
```yaml
serial_batch_size: 1
kernel_update_max_retries: 3
kernel_update_target_version: "latest"
```

### Role Variables

See `roles/kernel_update/defaults/main.yml` for all configurable variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `kernel_update_target_version` | `latest` | Kernel version to install |
| `kernel_update_release_version` | `""` | AL2023 release version |
| `kernel_update_check_only` | `false` | Dry run mode |
| `kernel_update_max_retries` | `3` | DNF operation retries |

---

## Reboot Process

**IMPORTANT:** This automation does **NOT** automatically reboot instances after kernel updates.

### Why No Automatic Reboot?

- **Control**: You decide when to reboot based on your maintenance windows
- **Safety**: Prevents unexpected downtime
- **Flexibility**: Allows for manual verification before reboot
- **Multi-instance**: Coordinate reboots across multiple instances

### Manual Reboot Options

#### Option 1: AWS CLI (Recommended)

```bash
# Single instance
aws ec2 reboot-instances --instance-ids $(terraform output -raw ec2_instance_id)

# Multiple instances
aws ec2 reboot-instances --instance-ids i-123456789 i-987654321
```

#### Option 2: Via SSM

```bash
aws ssm start-session --target $(terraform output -raw ec2_instance_id)
sudo reboot
```

#### Option 3: AWS Console

Navigate to EC2 console → Select instance → Instance state → Reboot instance

### Verification After Reboot

```bash
# Wait for instance to come back online
./verify_kernel.sh

# Or manually check
aws ssm start-session --target $(terraform output -raw ec2_instance_id)
uname -r
```

---

## Troubleshooting

### SSM Connectivity Issues

**Problem:** `ansible kernel_update_targets -m ping` fails

**Solutions:**

1. **Verify SSM agent is running:**
   ```bash
   aws ssm send-command \
     --instance-ids $INSTANCE_ID \
     --document-name "AWS-RunShellScript" \
     --parameters 'commands=["sudo systemctl status amazon-ssm-agent"]'
   ```

2. **Check instance connectivity:**
   ```bash
   aws ssm describe-instance-information \
     --filters "Key=InstanceIds,Values=$INSTANCE_ID"
   ```
   Look for `PingStatus: Online`

3. **Test direct SSM connection:**
   ```bash
   aws ssm start-session --target $INSTANCE_ID
   ```

4. **Increase timeout in `group_vars/all.yml`:**
   ```yaml
   ansible_aws_ssm_timeout: 120
   ```

### Kernel Update Failures

**Problem:** DNF fails to update kernel

**Solutions:**

1. **Check disk space:**
   ```bash
   ansible kernel_update_targets -i inventory/hosts.yml \
     -m command -a "df -h /"
   ```
   Ensure at least 2GB free space

2. **Check DNF logs on instance:**
   ```bash
   aws ssm start-session --target $INSTANCE_ID
   sudo tail -f /var/log/dnf.log
   ```

3. **Verify release version is valid:**
   ```bash
   ansible kernel_update_targets -i inventory/hosts.yml \
     -m command -a "dnf list available --releasever=2023.9.20251208 kernel"
   ```

### Terraform Execution Issues

**Problem:** Terraform apply fails during Ansible execution

**Solutions:**

1. **Check Ansible is installed:**
   ```bash
   which ansible-playbook
   ansible --version
   ```

2. **Verify collections are available:**
   ```bash
   ansible-galaxy collection list | grep community.aws
   ```

3. **Test Ansible manually:**
   ```bash
   cd ansible
   ansible-playbook playbooks/kernel_update.yml \
     -i inventory/hosts.yml \
     -e "kernel_update_check_only=true"
   ```

4. **Disable Ansible in Terraform:**
   ```bash
   terraform apply -var-file="dev.auto.tfvars" -var="run_ansible=false"
   ```

---

## Architecture

### Directory Structure

```
ansible/
├── ansible.cfg                          # Ansible configuration
├── requirements.yml                     # Collection dependencies
├── README.md                            # This file
│
├── inventory/
│   ├── hosts.yml                        # Auto-generated by Terraform
│   └── group_vars/
│       ├── all.yml                      # Global variables (SSM config)
│       └── kernel_update_targets.yml    # Target group variables
│
├── playbooks/
│   ├── kernel_update.yml                # Main update playbook
│   └── verify_kernel.yml                # Verification playbook
│
└── roles/
    └── kernel_update/
        ├── defaults/
        │   └── main.yml                 # Default variables
        ├── handlers/
        │   └── main.yml                 # Handlers (if needed)
        └── tasks/
            ├── main.yml                 # Task orchestration
            ├── preflight.yml            # Pre-update checks
            ├── update.yml               # Kernel update logic
            └── verify.yml               # Post-update verification
```

### Workflow

1. **Terraform** provisions infrastructure and generates inventory
2. **Terraform** (optionally) triggers Ansible via `null_resource`
3. **Ansible** connects via SSM and executes kernel update
4. **Preflight checks** capture current state and validate prerequisites
5. **Update tasks** install kernel via DNF
6. **Verify tasks** confirm packages were installed
7. **Manual reboot** activates new kernel (outside automation)

### Rolling Update Strategy

- **Serial execution**: Updates one instance at a time (configurable)
- **Fail-fast**: Stops on first failure (`max_fail_percentage: 0`)
- **Minimal blast radius**: Limits impact of failed updates
- **State verification**: Each instance verified before proceeding to next

---

## Available Commands Summary

| Command | Purpose |
|---------|---------|
| `./run_kernel_update.sh` | Update via Terraform (recommended) |
| `./run_kernel_update.sh latest 2023.9.20251208` | Update to specific release |
| `./verify_kernel.sh` | Check current kernel status |
| `terraform apply -var="run_ansible=true"` | Terraform-driven update |
| `ansible-playbook playbooks/kernel_update.yml` | Manual Ansible execution |
| `ansible kernel_update_targets -m ping` | Test SSM connectivity |
| `aws ec2 reboot-instances --instance-ids ID` | Reboot instance |

---

## Best Practices

1. **Always test in non-production first**
2. **Use check-only mode** before actual updates
3. **Verify kernel packages** before rebooting
4. **Coordinate reboots** across multiple instances
5. **Monitor CloudWatch logs** during updates
6. **Keep old kernels** for rollback capability
7. **Document release versions** used in production
8. **Test SSM connectivity** before starting updates
9. **Use serial updates** for production (default: 1 at a time)
10. **Plan maintenance windows** for reboots

---

## License

This project is part of the Cloud DevOps Projects portfolio.

---

## Changelog

- **2026-02-16**:
  - Initial implementation with SSM support
  - Terraform-driven Ansible execution
  - Removed automatic reboot (manual control)
  - Added rolling update support
