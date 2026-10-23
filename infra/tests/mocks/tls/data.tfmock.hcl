# No TLS connection is made; the certificate is a synthetic schema fixture.
mock_data "tls_certificate" {
  defaults = {
    certificates = [{
      cert_pem             = "mock-certificate"
      is_ca                = true
      issuer               = "CN=mock"
      max_path_length      = 0
      not_after            = "2030-01-01T00:00:00Z"
      not_before           = "2020-01-01T00:00:00Z"
      public_key_algorithm = "RSA"
      serial_number        = "1"
      sha1_fingerprint     = "0123456789abcdef0123456789abcdef01234567"
      signature_algorithm  = "SHA256-RSA"
      subject              = "CN=mock"
      version              = 3
    }]
  }
}
