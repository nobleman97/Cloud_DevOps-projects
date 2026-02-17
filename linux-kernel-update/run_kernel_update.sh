#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
LINUX_KERNEL_VERSION="${1:-}"
CHECK_ONLY="${2:-false}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Automated Linux Kernel Update${NC}"
echo -e "${BLUE}Terraform-Driven Execution${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Display execution parameters
echo -e "${GREEN}Execution Parameters:${NC}"
echo "  Linux Kernel Version: ${LINUX_KERNEL_VERSION:-latest available}"
echo "  Check Only Mode: ${CHECK_ONLY}"
echo ""

# Build Terraform variables
TF_VARS="-var-file=dev.auto.tfvars"
TF_VARS="${TF_VARS} -var run_ansible=true"
TF_VARS="${TF_VARS} -var ansible_check_only=${CHECK_ONLY}"

if [ -n "${LINUX_KERNEL_VERSION}" ]; then
    TF_VARS="${TF_VARS} -var linux_kernel_version=${LINUX_KERNEL_VERSION}"
fi

echo -e "${YELLOW}Running Terraform apply with Ansible execution...${NC}"
echo ""

# Run Terraform apply which will execute Ansible
terraform apply ${TF_VARS} || {
    echo -e "${RED}Terraform apply failed${NC}"
    exit 1
}

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Kernel Update Completed Successfully${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Reboot required to activate new kernel${NC}"
echo -e "${BLUE}Run './verify_kernel.sh' to check kernel status${NC}"
echo ""
echo -e "${BLUE}To reboot all instances:${NC}"
echo "  INSTANCE_IDS=\$(terraform output -json instance_ids | jq -r '.[]' | tr '\\n' ' ')"
echo "  aws ec2 reboot-instances --instance-ids \$INSTANCE_IDS"
echo ""
echo -e "${BLUE}Or reboot individual instances (adjust instance names as needed):${NC}"
terraform output -json instance_ids | jq -r 'to_entries[] | "  # " + .key + ": aws ec2 reboot-instances --instance-ids " + .value'
