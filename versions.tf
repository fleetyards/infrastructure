terraform {
  required_version = ">= 1.12.0"

  backend "s3" {
    endpoints = {
      s3 = "https://fsn1.your-objectstorage.com"
    }
    bucket = "fleetyards-terraform-state"
    key    = "terraform.tfstate"
    region = "fsn1"

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.50"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = ">= 2.3"
    }

    dnsimple = {
      source  = "dnsimple/dnsimple"
      version = ">= 1.8"
    }
  }
}
