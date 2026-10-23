# Synthetic provider responses only. Values under test stay in the real modules.
mock_data "aws_availability_zones" {
  defaults = {
    names = ["us-east-1a", "us-east-1b"]
  }
}

mock_data "aws_eks_addon_version" {
  defaults = {
    version = "v0.0.0-mock"
  }
}

mock_resource "aws_eks_cluster" {
  defaults = {
    certificate_authority = [{ data = "bW9jay1jZXJ0aWZpY2F0ZQ==" }]
    identity = [{
      oidc = [{ issuer = "https://oidc.example.invalid/id/mock" }]
    }]
  }
}
