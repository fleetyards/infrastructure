provider "hcloud" {
  token = var.hetzner_api_key
}

provider "dnsimple" {}

provider "aws" {
  region                      = "fsn1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_requesting_account_id  = true

  endpoints {
    s3 = "https://fsn1.your-objectstorage.com"
  }
}

provider "bunnynet" {
  api_key = var.bunny_api_key
}
