provider "hcloud" {
  token = data.onepassword_item.hetzner.credential
}

provider "dnsimple" {
  token   = data.onepassword_item.dnsimple.credential
  account = data.onepassword_item.dnsimple.username
}

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
  api_key = data.onepassword_item.bunny.credential
}
