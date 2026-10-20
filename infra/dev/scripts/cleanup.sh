#!/bin/bash

# Script to clean up the dev Terraform environment
# This script destroys dev resources only

set -euo pipefail

echo "=== Cleaning Up Dev Terraform Environment ==="
echo "WARNING: This will destroy ALL dev resources!"

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
read -p "Are you sure you want to destroy ALL dev resources? Type 'destroy' to confirm: " confirmation
if [[ "$confirmation" != "destroy" ]]; then
  echo "Cleanup cancelled"
  exit 0
fi

# Check AWS credentials
echo "Checking AWS credentials..."
aws sts get-caller-identity >/dev/null || {
  echo "ERROR: AWS credentials not configured or invalid"
  exit 1
}

# Destroy each module in reverse order
MODULES=("RDS" "AWS")  # Reverse order of creation

for module in "${MODULES[@]}"; do
  echo "Destroying infra/dev/$module..."
  (
    cd "infra/dev/$module"
    
    # Check backend configuration
    if ! grep -q "key.*dev/" terraform.tfstate; then
      echo "ERROR: Backend key does not contain 'dev/' prefix in $module"
      exit 1
    fi
    
    terraform init -input=false
    terraform destroy -auto-approve -input=false
  )
  echo "✓ $module destroyed successfully"
done

echo "=== All dev resources destroyed successfully ==="
echo "Dev environment has been cleaned up"