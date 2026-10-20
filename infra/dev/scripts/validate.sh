#!/bin/bash

# Script to validate the dev Terraform configurations
# This script ensures we're working with the dev environment only

set -euo pipefail

echo "=== Validating Dev Terraform Configurations ==="

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

# Validate each module
for module in AWS ACM RDS; do
  echo "Validating infra/dev/$module..."
  (
    cd "infra/dev/$module"
    terraform init -backend=false -input=false
    terraform validate
  )
  echo "✓ $module validation successful"
done

echo "=== All validations passed ==="