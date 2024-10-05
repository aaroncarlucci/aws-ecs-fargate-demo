resource "tls_private_key" "app_ssl" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "app_ssl" {
  private_key_pem = tls_private_key.app_ssl.private_key_pem

  # Certificate expires after 10 years for example
  validity_period_hours = 105120

  # Generate a new certificate if Terraform is run within one
  # month of the certificate's expiration time.
  early_renewal_hours = 744

  # Reasonable set of uses for a server SSL certificate
  allowed_uses = ["server_auth"]

  subject {
    common_name = "localhost"
  }
}
