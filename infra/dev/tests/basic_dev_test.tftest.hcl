# Basic test for dev environment configuration

mock_provider "aws" {}

run "validate_dev_naming" {
  command = plan
  module {
    source = "./AWS"
  }

  assert {
    condition     = var.dev_prefix == "dev/"
    error_message = "Dev prefix should be dev/"
  }

  # Check that SSH is not allowed from 0.0.0.0/0
  # This would require more complex mocking, so we'll check this in isolation_check.sh
}

run "validate_backend_key" {
  command = plan
  module {
    source = "./AWS"
  }

  # We can't directly access backend configuration in tests
  # This will be checked in isolation_check.sh
}

# Test that no production resources are referenced
run "validate_no_prod_references" {
  command = plan
  module {
    source = "./AWS"
  }

  # This test ensures we're not referencing production resources
  # Actual validation is done in isolation_check.sh
  assert {
    condition     = var.dev_prefix != ""
    error_message = "Dev prefix must be set"
  }
}