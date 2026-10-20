terraform {
  backend "s3" {
    bucket       = "marni-nextcloud-terraform-state"
    key          = "dev/nextcloud/RDS/terraform.tfstate"
    region       = "ca-central-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28.0"
    }
  }
}

provider "aws" {
  region = "ca-central-1"
}

# Variables for dev environment
variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = "devpassword123"  # Default for dev only
}

variable "dev_prefix" {
  description = "Prefix for dev resources"
  type        = string
  default     = "dev/"
}

# Data source for VPC - in dev we reference our own VPC
data "aws_vpc" "education_dev" {
  tags = {
    Name = "education-dev"
  }
}

data "aws_subnets" "education_dev_public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.education_dev.id]
  }
  
  filter {
    name   = "tag:Tier"
    values = ["public"]
  }
}

resource "aws_db_subnet_group" "education_dev" {
  name       = "education-dev"
  subnet_ids = data.aws_subnets.education_dev_public.ids

  tags = {
    Name = "Education-Dev"
  }
}

resource "aws_security_group" "rds_dev" {
  name   = "education_rds_dev"
  vpc_id = data.aws_vpc.education_dev.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]  # Dev VPC CIDR
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "education_rds_dev"
  }
}

resource "aws_db_parameter_group" "education_dev" {
  name   = "education-dev"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "education_dev" {
  identifier             = "education-dev"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  db_name                = "nextcloud_dev"
  engine_version         = "15"
  username               = "edu_dev"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.education_dev.name
  vpc_security_group_ids = [aws_security_group.rds_dev.id]
  parameter_group_name   = aws_db_parameter_group.education_dev.name
  publicly_accessible    = false
  skip_final_snapshot    = true

  tags = {
    Name = "education-dev-db"
  }
}

output "rds_endpoint_dev" {
  value = aws_db_instance.education_dev.endpoint
}

output "rds_database_name_dev" {
  value = aws_db_instance.education_dev.db_name
}