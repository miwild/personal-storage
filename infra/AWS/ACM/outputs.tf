output "client_vpn_client_certificate_arn" {
  description = "ARN of the ACM client certificate"
  value       = aws_acm_certificate.client_vpn_ca.arn
}

output "client_vpn_server_certificate_arn" {
  description = "ARN of the ACM server certificate for AWS Client VPN"
  value       = aws_acm_certificate.client_vpn_server.arn
}

output "client_vpn_ca_certificate_arn" {
  description = "ARN of the client CA certificate for AWS Client VPN"
  value       = aws_acm_certificate.client_vpn_root_ca.arn
}