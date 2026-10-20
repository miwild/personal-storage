#!/bin/bash

# Script to apply the dev Terraform configurations
# This script ensures we're working with the dev environment only
# WARNING: This script will create actual AWS resources

set -euo pipefail

echo "=== Applying Dev Terraform Configurations ==="
echo "WARNING: This will create actual AWS resources in your account!"

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

# Confirm before proceeding
read -p "Are you sure you want to apply the dev configuration? Type 'yes' to confirm: " confirmation
if [[ "$confirmation" != "yes" ]]; then
  echo "Apply cancelled"
  exit 0
fi

# Check AWS credentials
echo "Checking AWS credentials..."
aws sts get-caller-identity >/dev/null || {
  echo "ERROR: AWS credentials not configured or invalid"
  exit 1
}

# Apply each module in order
MODULES=("AWS" "RDS")  # ACM is minimal in dev

for module in "${MODULES[@]}"; do
  echo "Applying infra/dev/$module..."
  (
    cd "infra/dev/$module"
    
    # Check backend configuration
    if ! grep -q "key.*dev/" terraform.tfstate; then
      echo "ERROR: Backend key does not contain 'dev/' prefix in $module"
      exit 1
    fi
    
    # Check if plan exists
    if [[ ! -f tfplan ]]; then
      echo "ERROR: No plan found for $module. Please run plan.sh first"
      exit 1
    fi
    
    terraform apply -input=false tfplan
  )
  echo "✓ $module applied successfully"
done

echo "=== All modules applied successfully ==="
echo "Dev environment is now provisioned"