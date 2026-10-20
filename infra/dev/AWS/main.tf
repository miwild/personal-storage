terraform {
  backend "s3" {
    bucket       = "marni-nextcloud-terraform-state"
    key          = "dev/nextcloud/AWS/terraform.tfstate"
    region       = "ca-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

# Configure the Cloud Provider
provider "aws" {
  region = "ca-central-1"
}

# Variables for dev environment
variable "ssh_public_key" {
  type = string
  default = ""
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate notifications"
  type        = string
  default     = "makethingsappen@gmail.com"
}

variable "duckdns_token" {
  description = "DuckDNS token for DNS-01 ACME challenge"
  type        = string
  sensitive   = true
  default     = ""
}

variable "dev_prefix" {
  description = "Prefix for dev resources"
  type        = string
  default     = "dev/"
}

# Data sources for dev environment
# Note: In a full dev environment, we might want to avoid depending on production resources
# For now, we'll keep minimal dependencies

# 1. Create the Education VPC for dev
resource "aws_vpc" "education_dev" {
  cidr_block           = "10.1.0.0/16"  # Different CIDR than production
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "education-dev"
  }
}

# 2. Create public subnets in separate Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "education_dev_public_a" {
  vpc_id                  = aws_vpc.education_dev.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "education-dev-public-a"
    Tier = "public"
  }
}

resource "aws_subnet" "education_dev_public_b" {
  vpc_id                  = aws_vpc.education_dev.id
  cidr_block              = "10.1.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "education-dev-public-b"
    Tier = "public"
  }
}

# 3. Create an Internet Gateway
resource "aws_internet_gateway" "education_dev" {
  vpc_id = aws_vpc.education_dev.id

  tags = {
    Name = "education-dev-igw"
  }
}

# Create a public route table
resource "aws_route_table" "education_dev_public" {
  vpc_id = aws_vpc.education_dev.id

  tags = {
    Name = "education-dev-public-rt"
  }
}

# Route internet-bound traffic through the Internet Gateway
resource "aws_route" "education_dev_public_internet" {
  route_table_id         = aws_route_table.education_dev_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.education_dev.id
}

# Associate public subnet A with the public route table
resource "aws_route_table_association" "education_dev_public_a" {
  subnet_id      = aws_subnet.education_dev_public_a.id
  route_table_id = aws_route_table.education_dev_public.id
}

# Associate public subnet B with the public route table
resource "aws_route_table_association" "education_dev_public_b" {
  subnet_id      = aws_subnet.education_dev_public_b.id
  route_table_id = aws_route_table.education_dev_public.id
}

# Security group for dev environment - no public SSH
resource "aws_security_group" "k3s_sg_dev" {
  name        = "k3s-security-group-dev"
  description = "Allow Kubernetes API and Web traffic for dev"
  vpc_id      = aws_vpc.education_dev.id

  # No SSH from anywhere - dev environment is more secure
  # ingress {
  #   description = "SSH"
  #   from_port   = 22
  #   to_port     = 22
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 2. Dynamic Ubuntu 22.04 AMI Locator
data "aws_ami" "ubuntu_dev" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Outputs for dev environment
output "vpc_id_dev" {
  value = aws_vpc.education_dev.id
}

output "public_subnet_ids_dev" {
  value = [
    aws_subnet.education_dev_public_a.id,
    aws_subnet.education_dev_public_b.id
  ]
}