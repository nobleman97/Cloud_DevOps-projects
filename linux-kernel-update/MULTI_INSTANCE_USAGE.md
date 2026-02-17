# Multi-Instance Kernel Update Usage Guide

This guide explains how to use the refactored Terraform + Ansible automation with multiple EC2 instances using the `for_each` pattern.

## Overview

The infrastructure now supports managing multiple EC2 instances defined as a map in `dev.auto.tfvars`. Each instance is automatically added to the Ansible inventory for kernel updates.

## Configuration

### Define Instances (dev.auto.tfvars)

```hcl
instances = {
  "kiu-1" = {
    instance_type = "t2.micro"
    ami_id        = "ami-0fa3fe0fa7920f68e"
  }
  "kiu-2" = {
    instance_type = "t2.micro"
    ami_id        = "ami-0fa3fe0fa7920f68e"
  }
}
```

### Adding New Instances

Simply add new entries to the `instances` map:

```hcl
instances = {
  "kiu-1" = { ... }
  "kiu-2" = { ... }
  "kiu-3" = {
    instance_type = "t2.small"
    ami_id        = "ami-0fa3fe0fa7920f68e"
    tags = {
      Purpose = "Testing"
    }
  }
}
```

### Removing Instances

Remove the entry from the map and run `terraform apply`.

## Ansible Inventory Structure

The inventory is auto-generated with all instances:

```yaml
all:
  children:
    kernel_update_targets:
      hosts:
        i-0abcd1234:  # kiu-1 instance ID
          ansible_host: i-0abcd1234
          ansible_connection: aws_ssm
          ansible_aws_ssm_region: us-east-1
          private_ip: 10.0.1.10
          public_ip: 3.80.x.x
          instance_name: kiu-1
          environment: dev
        i-0abcd5678:  # kiu-2 instance ID
          ansible_host: i-0abcd5678
          ansible_connection: aws_ssm
          ansible_aws_ssm_region: us-east-1
          private_ip: 10.0.1.11
          public_ip: 3.80.x.x
          instance_name: kiu-2
          environment: dev
```

## Workflow

### 1. Provision Infrastructure

```bash
terraform apply -var-file="dev.auto.tfvars"
```

This creates all instances and generates the inventory file.

### 2. Verify Infrastructure

```bash
# View all instance IDs
terraform output instance_ids

# View private IPs
terraform output instance_private_ips

# View public IPs
terraform output instance_public_ips

# Check inventory file
cat ansible/inventory/hosts.yml
```

### 3. Test Ansible Connectivity

```bash
cd ansible
ansible kernel_update_targets -m ping -i inventory/hosts.yml
```

Expected output:
```
i-0abcd1234 | SUCCESS => { "ping": "pong" }
i-0abcd5678 | SUCCESS => { "ping": "pong" }
```

### 4. Run Kernel Update (Dry Run)

```bash
terraform apply \
  -var-file="dev.auto.tfvars" \
  -var="run_ansible=true" \
  -var="ansible_check_only=true"
```

This runs preflight checks without making changes.

### 5. Run Actual Kernel Update

```bash
# Via Terraform
terraform apply \
  -var-file="dev.auto.tfvars" \
  -var="run_ansible=true" \
  -var="ansible_kernel_version=latest"

# Or via wrapper script
./run_kernel_update.sh
```

### 6. Reboot Instances

**Option A: Reboot all instances**
```bash
INSTANCE_IDS=$(terraform output -json instance_ids | jq -r '.[]' | tr '\n' ' ')
aws ec2 reboot-instances --instance-ids $INSTANCE_IDS
```

**Option B: Reboot specific instance**
```bash
# Reboot kiu-1
aws ec2 reboot-instances --instance-ids $(terraform output -json instance_ids | jq -r '.["kiu-1"]')

# Reboot kiu-2
aws ec2 reboot-instances --instance-ids $(terraform output -json instance_ids | jq -r '.["kiu-2"]')
```

**Option C: Reboot one at a time with verification**
```bash
for instance in kiu-1 kiu-2; do
  echo "Rebooting $instance..."
  INSTANCE_ID=$(terraform output -json instance_ids | jq -r ".\"$instance\"")
  aws ec2 reboot-instances --instance-ids $INSTANCE_ID

  echo "Waiting for instance to come back online..."
  sleep 60

  echo "Verifying kernel on $instance..."
  ansible $INSTANCE_ID -m command -a "uname -r" -i ansible/inventory/hosts.yml
done
```

### 7. Verify Kernel Updates

```bash
./verify_kernel.sh
```

Or manually:
```bash
cd ansible
ansible-playbook playbooks/verify_kernel.yml -i inventory/hosts.yml
```

## Rolling Updates

### Serial Update (One at a Time) - Default

```bash
terraform apply \
  -var-file="dev.auto.tfvars" \
  -var="run_ansible=true" \
  -var="ansible_serial_batch_size=1"
```

Behavior:
1. Updates kiu-1
2. Waits for completion
3. Updates kiu-2
4. Stops on first failure

### Parallel Update (All at Once)

```bash
terraform apply \
  -var-file="dev.auto.tfvars" \
  -var="run_ansible=true" \
  -var="ansible_serial_batch_size=2"
```

For more than 2 instances, set batch size to match instance count.

### Custom Batch Size

For 10 instances, update 3 at a time:

```bash
terraform apply \
  -var-file="dev.auto.tfvars" \
  -var="run_ansible=true" \
  -var="ansible_serial_batch_size=3"
```

## Targeting Specific Instances

### Update Only Specific Instances

Use Ansible directly with `--limit`:

```bash
cd ansible

# Update only kiu-1
ansible-playbook playbooks/kernel_update.yml \
  -i inventory/hosts.yml \
  --limit "$(terraform output -json instance_ids | jq -r '.["kiu-1"]')"

# Update only kiu-1 and kiu-2
ansible-playbook playbooks/kernel_update.yml \
  -i inventory/hosts.yml \
  --limit "$(terraform output -json instance_ids | jq -r '.["kiu-1"],.["kiu-2"]' | tr '\n' ',')"
```

### Exclude Specific Instances

```bash
# Update all except kiu-2
ansible-playbook playbooks/kernel_update.yml \
  -i inventory/hosts.yml \
  --limit 'kernel_update_targets:!$(terraform output -json instance_ids | jq -r ".\"kiu-2\"")'
```

## Terraform Outputs

### Get Instance Information

```bash
# All instance IDs as map
terraform output instance_ids
# Output: {
#   "kiu-1" = "i-0abcd1234"
#   "kiu-2" = "i-0abcd5678"
# }

# Specific instance ID
terraform output -json instance_ids | jq -r '.["kiu-1"]'
# Output: i-0abcd1234

# All IDs as space-separated list (for AWS CLI)
terraform output -json instance_ids | jq -r '.[]' | tr '\n' ' '
# Output: i-0abcd1234 i-0abcd5678

# All private IPs
terraform output instance_private_ips

# All public IPs
terraform output instance_public_ips

# Full inventory content
terraform output ansible_inventory
```

## Advanced Usage

### Update to Specific Release Version

```bash
terraform apply \
  -var-file="dev.auto.tfvars" \
  -var="run_ansible=true" \
  -var="ansible_release_version=2023.9.20251208"
```

### Mixed Updates

Update different instances to different versions:

```bash
cd ansible

# Update kiu-1 to latest
ansible-playbook playbooks/kernel_update.yml \
  -i inventory/hosts.yml \
  --limit "$(terraform output -json instance_ids | jq -r '.["kiu-1"]')" \
  -e "kernel_version=latest"

# Update kiu-2 to specific release
ansible-playbook playbooks/kernel_update.yml \
  -i inventory/hosts.yml \
  --limit "$(terraform output -json instance_ids | jq -r '.["kiu-2"]')" \
  -e "release_version=2023.9.20251208"
```

## Troubleshooting

### Instance Not in Inventory

**Problem:** Newly added instance not showing in inventory

**Solution:**
```bash
# Regenerate inventory
terraform apply -target=local_file.ansible_inventory -var-file="dev.auto.tfvars"

# Verify
cat ansible/inventory/hosts.yml
```

### SSM Connectivity Issues

**Problem:** Cannot connect to instances via SSM

**Solution:**
```bash
# Check SSM agent status for all instances
for id in $(terraform output -json instance_ids | jq -r '.[]'); do
  echo "Checking $id..."
  aws ssm describe-instance-information --filters "Key=InstanceIds,Values=$id"
done

# Wait for SSM agent (after instance creation)
sleep 60

# Test direct connection
aws ssm start-session --target $(terraform output -json instance_ids | jq -r '.["kiu-1"]')
```

### Ansible Fails on Subset of Instances

**Problem:** Some instances fail during update

**Solution:**
```bash
# Check which instances failed
cd ansible
ansible-playbook playbooks/verify_kernel.yml -i inventory/hosts.yml

# Retry only failed instances using Ansible's retry file
ansible-playbook playbooks/kernel_update.yml -i inventory/hosts.yml --limit @retry/kernel_update.retry
```

## Best Practices

1. **Start Small**: Test with 1-2 instances before scaling
2. **Use Serial Updates**: Default `serial_batch_size=1` for production
3. **Verify Before Reboot**: Run verify playbook after update, before reboot
4. **Stagger Reboots**: Don't reboot all instances simultaneously
5. **Monitor CloudWatch**: Enable detailed monitoring during updates
6. **Test Rollback**: Practice rolling back to previous kernel in dev
7. **Document Versions**: Track which kernel versions are on which instances
8. **Use Tags**: Add purpose/role tags to instances for easier management

## Example: Complete Update Workflow

```bash
# 1. Create/update infrastructure
terraform apply -var-file="dev.auto.tfvars"

# 2. Verify all instances are healthy
cd ansible
ansible kernel_update_targets -m ping -i inventory/hosts.yml

# 3. Dry run to check for updates
cd ..
terraform apply \
  -var-file="dev.auto.tfvars" \
  -var="run_ansible=true" \
  -var="ansible_check_only=true"

# 4. Run actual update (serial, one at a time)
terraform apply \
  -var-file="dev.auto.tfvars" \
  -var="run_ansible=true"

# 5. Verify packages installed
./verify_kernel.sh

# 6. Reboot instances one at a time
for instance in kiu-1 kiu-2; do
  echo "Rebooting $instance..."
  INSTANCE_ID=$(terraform output -json instance_ids | jq -r ".\"$instance\"")
  aws ec2 reboot-instances --instance-ids $INSTANCE_ID
  echo "Waiting 90 seconds..."
  sleep 90
done

# 7. Final verification
./verify_kernel.sh

# 8. Confirm new kernel loaded on all instances
cd ansible
ansible kernel_update_targets -m command -a "uname -r" -i inventory/hosts.yml
```

## Reference

- **Main README**: [README.md](README.md)
- **Ansible Details**: [ansible/README.md](ansible/README.md)
- **Terraform Variables**: [variables.tf](variables.tf)
- **Instance Config**: [dev.auto.tfvars](dev.auto.tfvars)
