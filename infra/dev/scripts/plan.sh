#!/bin/bash

# Script to plan the dev Terraform configurations
# This script ensures we're working with the dev environment only

set -euo pipefail

DEV_ACCOUNT_ID="${DEV_ACCOUNT_ID:-}"
REGION="ca-central-1"

# Check that DEV_ACCOUNT_ID is set
if [[ -z "$DEV_ACCOUNT_ID" ]]; then
  echo "ERROR: DEV_ACCOUNT_ID environment variable must be set"
  exit 1
fi

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

# Check AWS credentials match required dev account
CREDENTIALS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null)
if [[ "$CREDENTIALS_ACCOUNT_ID" != "$DEV_ACCOUNT_ID" ]]; then
  echo "ERROR: AWS credentials do not match required dev account ID"
  echo "Expected: $DEV_ACCOUNT_ID"
  echo "Found: $CREDENTIALS_ACCOUNT_ID"
  exit 1
fi

echo "✓ AWS credentials verified for dev account"

# Check AWS region
CONFIGURED_REGION=$(aws configure get region 2>/dev/null)
if [[ "$CONFIGURED_REGION" != "$REGION" ]]; then
  echo "ERROR: AWS region must be set to $REGION"
  echo "Current region: $CONFIGURED_REGION"
  exit 1
fi

echo "✓ AWS region verified as $REGION"

# Initialize and plan each module in order
MODULES=("AWS" "RDS")  # ACM is minimal in dev

for module in "${MODULES[@]}"; do
  echo "Planning infra/dev/$module..."
  (
    cd "infra/dev/$module"
    
    # Check backend configuration
    BACKEND_KEY=$(grep -o "key.*\"[^\"]*\".*" main.tf | cut -d\" -f2)
    if [[ ! "$BACKEND_KEY" =~ ^dev/ ]]; then
      echo "ERROR: Backend key does not start with 'dev/' prefix in $module"
      echo "Found: $BACKEND_KEY"
      exit 1
    fi
    
    echo "✓ Backend key verified: $BACKEND_KEY"
    
    terraform init -input=false
    terraform plan -input=false -out=tfplan
  )
  echo "✓ $module plan successful"
done

echo "=== All plans generated successfully ==="
echo "Plans are stored in each module's tfplan file"
echo "To apply, run the apply.sh script"