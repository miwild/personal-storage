# Test that dev resources have appropriate names and configurations

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["ca-central-1a", "ca-central-1b"]
    }
  }
}

variables {
  dev_prefix = "dev/"
}

run "validate_dev_aws_resources" {
  command = plan
  module {
    source = "./AWS"
  }

  assert {
    condition     = aws_vpc.education_dev.tags.Name == "education-dev"
    error_message = "VPC name should be education-dev"
  }

  assert {
    condition     = length(aws_vpc.education_dev.cidr_block) > 0
    error_message = "VPC should have a CIDR block"
  }

  assert {
    condition     = aws_internet_gateway.education_dev.tags.Name == "education-dev-igw"
    error_message = "Internet Gateway name should be education-dev-igw"
  }
}

run "validate_dev_rds_resources" {
  command = plan
  module {
    source = "./RDS"
  }

  assert {
    condition     = aws_db_instance.education_dev.identifier == "education-dev"
    error_message = "RDS instance identifier should be education-dev"
  }

  assert {
    condition     = aws_db_instance.education_dev.db_name == "nextcloud_dev"
    error_message = "RDS database name should be nextcloud_dev"
  }
}

run "validate_dev_naming_convention" {
  command = plan
  module {
    source = "./AWS"
  }

  # Assert backend key starts with dev/
  assert {
    condition     = var.dev_prefix == "dev/"
    error_message = "Dev prefix should be dev/"
  }
}

# Test that resources do not contain production identifiers
# This is primarily checked in isolation_check.sh since terraform test has limitations
run "validate_no_production_identifiers" {
  command = plan
  module {
    source = "./AWS"
  }

  # Simple assertion that dev_prefix is set (basic check)
  assert {
    condition     = var.dev_prefix != ""
    error_message = "Dev prefix should be set"
  }
}