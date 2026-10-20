#!/bin/bash

# Script to check that dev environment doesn't reference production resources

set -euo pipefail

echo "=== Checking Dev Environment Isolation ==="

# Check that we're in the right directory
if [[ ! -d "infra/dev" ]]; then
  echo "ERROR: Must run this script from the repository root"
  exit 1
fi

# Find all Terraform files
TF_FILES=$(find infra/dev -name "*.tf" 2>/dev/null)
if [[ -z "$TF_FILES" ]]; then
  echo "WARNING: No Terraform files found"
  exit 0
fi

# Check for production DuckDNS record - EXACT MATCH ONLY
if echo "$TF_FILES" | xargs grep -q "nextcloud-demo-flourishing" 2>/dev/null; then
  echo "ERROR: Found production DuckDNS record reference (nextcloud-demo-flourishing)"
  echo "$TF_FILES" | xargs grep -n "nextcloud-demo-flourishing" || true
  exit 1
fi

echo "✓ No production DuckDNS record references found"

# Check for production tag - EXACT MATCH ONLY
if echo "$TF_FILES" | xargs grep -q "k3s-nextcloud-host" 2>/dev/null; then
  echo "ERROR: Found production tag k3s-nextcloud-host"
  echo "$TF_FILES" | xargs grep -n "k3s-nextcloud-host" || true
  exit 1
fi

echo "✓ No production tag references found"

# Check for production secrets - EXACT MATCH ONLY
if echo "$TF_FILES" | xargs grep -q "marni-macbook-key" 2>/dev/null; then
  echo "ERROR: Found production secret marni-macbook-key"
  echo "$TF_FILES" | xargs grep -n "marni-macbook-key" || true
  exit 1
fi

echo "✓ No production secret references found"

# Check backend configurations
BACKEND_FILES=$(echo "$TF_FILES" | xargs grep -l "backend" 2>/dev/null || true)
if [[ -n "$BACKEND_FILES" ]]; then
  # Check that all state keys start with dev/
  BACKEND_MATCH=$(echo "$BACKEND_FILES" | xargs grep "key" 2>/dev/null | grep "dev/" || true)
  if [[ -z "$BACKEND_MATCH" ]]; then
    echo "ERROR: Backend keys do not start with dev/ prefix"
    echo "$BACKEND_FILES" | xargs grep -n "key" || true
    exit 1
  fi
  
  echo "✓ Backend configurations are properly isolated"
else
  echo "WARNING: No backend configuration files found"
fi

echo "=== Isolation check completed successfully ==="