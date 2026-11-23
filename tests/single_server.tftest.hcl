mock_provider "hcloud" {}
mock_provider "aws" {}
mock_provider "bunnynet" {}
mock_provider "onepassword" {}
mock_provider "cloudflare" {}

override_module {
  target = module.r2_backups
  outputs = {
    bucket            = "fltyrd-default-backups"
    endpoint          = "https://mock-account.r2.cloudflarestorage.com"
    access_key_id     = "mock-access-key-id"
    secret_access_key = "mock-secret-access-key"
  }
}

run "create_servers" {
  command = plan

  assert {
    condition     = hcloud_server.web_server.*.name == ["fltyrd-default-web"]
    error_message = "Server name is not correct"
  }

  assert {
    condition     = hcloud_load_balancer.web_load_balancer == []
    error_message = "Load balancer was created"
  }

  assert {
    condition     = can(regex("web", data.cloudinit_config.web_server_config[0].part[0].content))
    error_message = "Cloud-init config for fltyrd-web is not correct"
  }

  assert {
    condition     = can(regex("accessories", data.cloudinit_config.accessories_config[0].part[0].content))
    error_message = "Cloud-init config for fltyrd-accessories is not correct"
  }

  assert {
    condition     = onepassword_item.r2_backups.username == "mock-access-key-id" && onepassword_item.r2_backups.section[0].field[0].value == "fltyrd-default-backups"
    error_message = "The R2 backups item should carry the bucket's S3 credentials and name"
  }

  assert {
    condition     = bunnynet_storage_zone.uploads.type == "S3"
    error_message = "The uploads storage zone needs S3 compatibility, which can only be set when the zone is created"
  }

  assert {
    condition     = bunnynet_pullzone.storage.origin.type == "OriginUrl" && bunnynet_pullzone.storage.origin.url == "https://fsn1.your-objectstorage.com/fltyrd-default-storage"
    error_message = "The storage pull zone should keep pulling from the Hetzner bucket while storage_origin is hetzner"
  }

  assert {
    condition     = bunnynet_pullzone.storage.routing.tier == "Standard"
    error_message = "The storage pull zone should default to the Standard routing tier"
  }
}
