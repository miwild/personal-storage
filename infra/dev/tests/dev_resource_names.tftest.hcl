# Test that dev resources have appropriate names and configurations

variables {
  dev_prefix = "dev/"
}

run "validate_dev_aws_resources" {
  command = plan
  module {
    source = "../AWS"
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
    source = "../RDS"
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