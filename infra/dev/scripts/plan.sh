#!/bin/bash

# Script to plan the dev Terraform configurations
# This script ensures we're working with the dev environment only

set -euo pipefail

echo "=== Planning Dev Terraform Configurations ==="

# Check that we're in the right directory
if [[ ! -d "infra/dev" ]]; then
  echo "ERROR: Must run this script from the repository root"
  exit 1
fi

# Check that we're on the dev branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "dev-environment" ]]; then
  echo "WARNING: Not on dev-environment branch (currently on $CURRENT_BRANCH)"
  echo "Please switch to dev-environment branch for dev work"
fi

# Initialize and plan each module in order
MODULES=("AWS" "RDS")  # ACM is minimal in dev

for module in "${MODULES[@]}"; do
  echo "Planning infra/dev/$module..."
  (
    cd "infra/dev/$module"
    
    # Check backend configuration
    if ! grep -q "key.*dev/" terraform.tfstate; then
      echo "ERROR: Backend key does not contain 'dev/' prefix in $module"
      exit 1
    fi
    
    terraform init -input=false
    terraform plan -input=false -out=tfplan
  )
  echo "✓ $module plan successful"
done

echo "=== All plans generated successfully ==="
echo "Plans are stored in each module's tfplan file"
echo "To apply, run the apply.sh script"