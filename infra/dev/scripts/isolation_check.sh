#!/bin/bash

# Script to check that dev environment doesn't reference production resources

set -euo pipefail

echo "=== Checking Dev Environment Isolation ==="

# Check that we're in the right directory
if [[ ! -d "infra/dev" ]]; then
  echo "ERROR: Must run this script from the repository root"
  exit 1
fi

# Check backend keys don't reference production paths
echo "Checking backend configurations..."
if find infra/dev -name "*.tf" -exec grep -l "sandbox/nextcloud" {} \; 2>/dev/null | grep -q .; then
  echo "ERROR: Found production backend references in dev configuration"
  find infra/dev -name "*.tf" -exec grep -n "sandbox/nextcloud" {} +
  exit 1
else
  echo "✓ No production backend references found"
fi

# Check resource names don't reference production names
echo "Checking resource names..."
PRODUCTION_NAMES=("education" "k3s-nextcloud-host" "marni-macbook-key")
for name in "${PRODUCTION_NAMES[@]}"; do
  if find infra/dev -name "*.tf" -exec grep -l "\"$name\"" {} \; >/dev/null; then
    # Allow some exceptions like variables or comments
    if ! find infra/dev -name "*.tf" -exec grep -l "\"$name\"" {} \; | xargs grep -v "//\|#\|variable\|comment" >/dev/null 2>&1; then
      echo "WARNING: Found potential production name reference: $name"
      find infra/dev -name "*.tf" -exec grep -n "\"$name\"" {} +
    fi
  fi
done

echo "Checking for dev-specific naming..."
if find infra/dev -name "*.tf" -exec grep -l "_dev" {} \; >/dev/null; then
  echo "✓ Found dev-specific naming conventions"
else
  echo "WARNING: No dev-specific naming found - please ensure resources are properly named"
fi

# Check that backend keys use dev prefix
echo "Checking backend keys use dev prefix..."
if find infra/dev -name "backend*.tf" -o -name "main.tf" | xargs grep -l "key.*dev/" >/dev/null; then
  echo "✓ Backend keys use dev prefix"
else
  echo "ERROR: Backend keys do not use dev prefix"
  exit 1
fi

echo "=== Isolation check completed ==="