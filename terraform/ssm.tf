resource "aws_ssm_parameter" "app_ssl_key" {
  description = "The self-signed SSL certificate key for the ECS application tasks."
  # Parameter name cannot start with "aws", so using the awkward /terraform namespace
  name  = "/terraform/${local.application_name}/${var.environment}/ssl-certificate-key"
  type  = "SecureString"
  value = trimspace(tls_private_key.app_ssl.private_key_pem)
}

resource "aws_ssm_parameter" "app_ssl_cert" {
  description = "The self-signed SSL certificate for the ECS application tasks."
  # Parameter name cannot start with "aws", so using the awkward /terraform namespace
  name  = "/terraform/${local.application_name}/${var.environment}/ssl-certificate"
  type  = "SecureString"
  value = tls_self_signed_cert.app_ssl.cert_pem
}
