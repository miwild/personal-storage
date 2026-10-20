terraform {
  backend "s3" {
    bucket       = "marni-nextcloud-terraform-state"
    key          = "sandbox/nextcloud/AWS/terraform.tfstate"
    region       = "ca-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

# Configure the Cloud Provider
provider "aws" {
  region = "ca-central-1"
}

data "terraform_remote_state" "acm" {
  backend = "s3"

  config = {
    bucket = "marni-nextcloud-terraform-state"
    key    = "sandbox/nextcloud/ACM/terraform.tfstate"
    region = "ca-central-1"
  }
}

# 1. Create the Education VPC
resource "aws_vpc" "education" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "education"
  }
}

# 2. Create public subnets in separate Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "education_public_a" {
  vpc_id                  = aws_vpc.education.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "education-public-a"
    Tier = "public"
  }
}

resource "aws_subnet" "education_public_b" {
  vpc_id                  = aws_vpc.education.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name = "education-public-b"
    Tier = "public"
  }
}

# 3. Create an Internet Gateway
resource "aws_internet_gateway" "education" {
  vpc_id = aws_vpc.education.id

  tags = {
    Name = "education-igw"
  }
}

# Create a public route table
resource "aws_route_table" "education_public" {
  vpc_id = aws_vpc.education.id

  tags = {
    Name = "education-public-rt"
  }
}

# Route internet-bound traffic through the Internet Gateway
resource "aws_route" "education_public_internet" {
  route_table_id         = aws_route_table.education_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.education.id
}

# Associate public subnet A with the public route table
resource "aws_route_table_association" "education_public_a" {
  subnet_id      = aws_subnet.education_public_a.id
  route_table_id = aws_route_table.education_public.id
}

# Associate public subnet B with the public route table
resource "aws_route_table_association" "education_public_b" {
  subnet_id      = aws_subnet.education_public_b.id
  route_table_id = aws_route_table.education_public.id
}

variable "ssh_public_key" {
  type = string
}

# Create a Security Group for K3s (API server + HTTP/HTTPS)
resource "aws_security_group" "k3s_sg" {
  name        = "k3s-security-group"
  description = "Allow Kubernetes API and Web traffic"
  vpc_id      = aws_vpc.education.id

  ingress {
    description     = "SSH from Client VPN"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.client_vpn.id]
  }

  ingress {
    description     = "Kubernetes API from Client VPN"
    from_port       = 6443
    to_port         = 6443
    protocol        = "tcp"
    security_groups = [aws_security_group.client_vpn.id]
  }

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
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# Security group attached to the Client VPN endpoint
resource "aws_security_group" "client_vpn" {
  name        = "education-client-vpn"
  description = "Security group for AWS Client VPN"
  vpc_id      = aws_vpc.education.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "education-client-vpn"
  }
}

# AWS Client VPN endpoint
resource "aws_ec2_client_vpn_endpoint" "education" {
  description            = "Education Client VPN"
  server_certificate_arn = data.terraform_remote_state.acm.outputs.client_vpn_server_certificate_arn
  client_cidr_block      = "172.16.0.0/22"
  split_tunnel           = true
  transport_protocol     = "udp"
  vpn_port               = 443
  vpc_id                 = aws_vpc.education.id
  security_group_ids     = [aws_security_group.client_vpn.id]

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = data.terraform_remote_state.acm.outputs.client_vpn_ca_certificate_arn
  }

  connection_log_options {
    enabled = false
  }

  tags = {
    Name = "education-client-vpn"
  }
}

# Associate the Client VPN with public subnet A
resource "aws_ec2_client_vpn_network_association" "education" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.education.id
  subnet_id              = aws_subnet.education_public_a.id
}

# Authorize VPN clients to access the VPC
resource "aws_ec2_client_vpn_authorization_rule" "education" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.education.id
  target_network_cidr    = aws_vpc.education.cidr_block
  authorize_all_groups   = true
}

# 3. Provision the Managed Virtual Machine
resource "aws_instance" "k3s_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium"
  key_name                    = aws_key_pair.mac_key.key_name
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.education_public_a.id
  vpc_security_group_ids      = [aws_security_group.k3s_sg.id]

  depends_on = [
    aws_iam_role_policy_attachment.ssm_core
  ]

  iam_instance_profile = aws_iam_instance_profile.k3s_ssm_profile.name

  # Boot script to install K3s and output configuration keys
  user_data = <<-EOF
        #!/bin/bash
        set -euxo pipefail

        exec > >(tee -a /var/log/k3s-bootstrap.log) 2>&1

        echo "=== BOOTSTRAP START ==="
        date
        hostname

        echo "=== NETWORK ==="
        ip addr
        ip route

        echo "=== UFW BEFORE ==="
        ufw status verbose || true
        ufw disable || true
        ufw status verbose || true

        echo "=== SSH ==="
        systemctl status ssh --no-pager || true
        ss -lntp | grep ':22' || true

        echo "=== INTERNET TEST ==="
        curl -v --connect-timeout 10 https://get.k3s.io -o /tmp/install-k3s.sh

        # Add configuration for K3s-managed Traefik.
        # 1. Create the manifests directory ahead of time
        mkdir -p /var/lib/rancher/k3s/server/manifests

        # 2. Drop the Traefik HelmChartConfig in place with your token
        cat > /var/lib/rancher/k3s/server/manifests/traefik-config.yaml <<EOF_TRAEFIK
        apiVersion: helm.cattle.io/v1
        kind: HelmChartConfig
        metadata:
            name: traefik
            namespace: kube-system
        spec:
            valuesContent: |
                additionalArguments:
                    - "--entrypoints.web.http.redirections.entrypoint.to=:443"
                    - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
                    - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
                certificatesResolvers:
                    letsencrypt:
                        acme:
                            email: "${var.letsencrypt_email}"
                            storage: "/data/acme.json"
                            dnsChallenge:
                                provider: "duckdns"
                env:
                    - name: "DUCKDNS_TOKEN"
                      value: "${var.duckdns_token}"
                accessLog:
                    enabled: true
                persistence:
                    enabled: true
                    name: data
                    path: /data
                    size: 128Mi
        EOF_TRAEFIK

        # 3. Now install and start K3s. It will read the file on its initial boot sequence automatically.
        echo "INSTALLING K3S"
        INSTALL_K3S_VERSION="${var.k3s_version}" sh /tmp/install-k3s.sh \
            --tls-san ${aws_eip.k3s_ip.public_ip}

        echo "=== CONFIGURING TRAEFIK LETS ENCRYPT ==="

        # Wait for the Kubernetes API.
        until /usr/local/bin/k3s kubectl get nodes >/dev/null 2>&1; do
        sleep 5
        done

        echo "=== K3S STATUS ==="
        systemctl status k3s --no-pager || true

        echo "=== LISTENING PORTS ==="
        ss -lntp || true

        echo "=== BOOTSTRAP COMPLETE ==="
        date
        echo "=== KUBERNETES NODES ==="
        /usr/local/bin/k3s kubectl get nodes -o wide || true
        EOF

  tags = {
    Name = "k3s-nextcloud-host"
  }
}

# 4. SSH Key Pair
resource "aws_key_pair" "mac_key" {
  key_name   = "marni-macbook-key"
  public_key = var.ssh_public_key
}

# 5. Create System Role for Secure Data Syncing
resource "aws_iam_role" "k3s_ssm" {
  name = "k3s-ssm-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.k3s_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "k3s_ssm_profile" {
  name = "k3s-ssm-instance-profile"
  role = aws_iam_role.k3s_ssm.name
}

# Output the Public IP
output "k3s_public_ip" {
  value       = aws_eip.k3s_ip.public_ip
  description = "The public IP of your K3s server"
}

output "client_vpn_endpoint_id" {
  description = "AWS Client VPN endpoint ID"
  value       = aws_ec2_client_vpn_endpoint.education.id
}

output "vpc_id" {
  value = aws_vpc.education.id
}

output "public_subnet_ids" {
  value = [
    aws_subnet.education_public_a.id,
    aws_subnet.education_public_b.id
  ]
}

resource "aws_eip" "k3s_ip" {
  domain = "vpc"
}

resource "aws_eip_association" "k3s_assoc" {
  instance_id   = aws_instance.k3s_server.id
  allocation_id = aws_eip.k3s_ip.id
}

output "client_vpn_cidr" {
  value = aws_ec2_client_vpn_endpoint.education.client_cidr_block
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
}

variable "k3s_version" {
  description = "K3s release to install, e.g. v1.34.1+k3s1"
  type        = string
  default     = "v1.37.1+k3s1"
}