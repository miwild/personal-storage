terraform {
  backend "s3" {
    bucket       = "marni-nextcloud-terraform-state"
    key          = "sandbox/nextcloud/RDS/terraform.tfstate"
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

data "terraform_remote_state" "aws" {
  backend = "s3"

  config = {
    bucket = "marni-nextcloud-terraform-state"
    key    = "sandbox/nextcloud/AWS/terraform.tfstate"
    region = "ca-central-1"
  }
}

resource "aws_db_subnet_group" "education" {
  name       = "education"
  subnet_ids = data.terraform_remote_state.aws.outputs.public_subnet_ids

  tags = {
    Name = "Education"
  }
}

resource "aws_security_group" "rds" {
  name   = "education_rds"
  vpc_id = data.terraform_remote_state.aws.outputs.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    description = "PostgreSQL from Client VPN clients"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.aws.outputs.client_vpn_cidr]
  }

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "education_rds"
  }
}

resource "aws_db_parameter_group" "education" {
  name   = "education"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }
}

resource "aws_db_instance" "education" {
  identifier             = "education"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  db_name                = "nextcloud"
  engine_version         = "15"
  username               = "edu"
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.education.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.education.name
  publicly_accessible    = false
  skip_final_snapshot    = true
}