# Provider AWS apuntado a Floci (emulador local).
# No se usan credenciales reales: ver constitution, principio II.
provider "aws" {
  region = var.region

  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    acm             = "http://localhost:4566"
    autoscaling     = "http://localhost:4566"
    ec2             = "http://localhost:4566"
    ecr             = "http://localhost:4566"
    eks             = "http://localhost:4566"
    elbv2           = "http://localhost:4566"
    iam             = "http://localhost:4566"
    kms             = "http://localhost:4566"
    logs            = "http://localhost:4566"
    networkfirewall = "http://localhost:4566"
    sts             = "http://localhost:4566"
    wafv2           = "http://localhost:4566"
  }
}
