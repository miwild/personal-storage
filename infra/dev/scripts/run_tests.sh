#!/bin/bash

# Simple test script to verify dev environment meets requirements

set -euo pipefail

echo "=== Running Dev Environment Tests ==="

# Test 1: Verify backend keys use dev prefix
echo "Test 1: Checking backend keys use dev prefix..."
if find infra/dev -name "*.tf" -exec grep -l "key.*dev/" {} \; 2>/dev/null | grep -q .; then
  echo "✓ PASS: Backend keys use dev prefix"
else
  echo "✗ FAIL: Backend keys do not use dev prefix"
  exit 1
fi

# Test 2: Verify no production backend references
echo "Test 2: Checking for production backend references..."
if find infra/dev -name "*.tf" -exec grep -l "sandbox/nextcloud" {} \; 2>/dev/null | grep -q .; then
  echo "✗ FAIL: Found production backend references"
  exit 1
else
  echo "✓ PASS: No production backend references found"
fi

# Test 3: Verify dev-specific naming
echo "Test 3: Checking for dev-specific naming..."
if find infra/dev -name "*.tf" -exec grep -l "_dev" {} \; 2>/dev/null | grep -q .; then
  echo "✓ PASS: Found dev-specific naming conventions"
else
  echo "⚠ WARNING: No obvious dev-specific naming found"
fi

# Test 4: Verify no public SSH access
echo "Test 4: Checking for public SSH access..."
if find infra/dev -name "*.tf" -exec grep -l "from_port.*22" {} \; 2>/dev/null | grep -q .; then
  # Check if it's restricted
  if find infra/dev -name "*.tf" -exec grep -l "cidr_blocks.*0.0.0.0/0.*from_port.*22" {} \; 2>/dev/null | grep -q .; then
    echo "✗ FAIL: Found unrestricted SSH access"
    exit 1
  else
    echo "✓ PASS: No unrestricted SSH access found"
  fi
else
  echo "✓ PASS: No SSH access rules found (more secure)"
fi

echo "=== All tests completed ==="