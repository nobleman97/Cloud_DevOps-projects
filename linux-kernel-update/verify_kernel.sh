#!/bin/bash

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Kernel Version Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

cd ansible

# Run verification playbook
ansible-playbook playbooks/verify_kernel.yml \
    -i inventory/hosts.yml

echo ""
echo -e "${GREEN}Verification complete${NC}"
