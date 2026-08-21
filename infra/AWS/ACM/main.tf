variable "vpn_pki_path" {
  type = string
}

terraform {
  backend "s3" {
    bucket       = "marni-nextcloud-terraform-state"
    key          = "sandbox/nextcloud/ACM/terraform.tfstate"
    region       = "ca-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

resource "aws_acm_certificate" "client_vpn_ca" {
  private_key_wo         = file("${var.vpn_pki_path}/private/client1.domain.tld.key")
  private_key_wo_version = 1

  certificate_body  = file("${var.vpn_pki_path}/issued/client1.domain.tld.crt")
  certificate_chain = file("${var.vpn_pki_path}/ca.crt")

  tags = {
    Name = "client-vpn-client-certificate"
  }
}

resource "aws_acm_certificate" "client_vpn_server" {
  private_key_wo         = file("${var.vpn_pki_path}/private/server.key")
  private_key_wo_version = 1

  certificate_body  = file("${var.vpn_pki_path}/issued/server.crt")
  certificate_chain = file("${var.vpn_pki_path}/ca.crt")

  tags = {
    Name = "client-vpn-server-certificate"
  }
}

resource "aws_acm_certificate" "client_vpn_root_ca" {
  private_key_wo         = file("${var.vpn_pki_path}/private/ca.key")
  private_key_wo_version = 1

  certificate_body = file("${var.vpn_pki_path}/ca.crt")

  tags = {
    Name = "client-vpn-root-ca"
  }
}