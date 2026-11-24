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

override_module {
  target = module.r2_sc_data
  outputs = {
    bucket   = "fltyrd-sc"
    endpoint = "https://mock-account.r2.cloudflarestorage.com"
    credentials = {
      read  = { access_key_id = "mock-read-id", secret_access_key = "mock-read-secret" }
      write = { access_key_id = "mock-write-id", secret_access_key = "mock-write-secret" }
    }
  }
}

variables {
  env_config = {
    default = {
      web_server_types        = ["cx33", "cx23"]
      accessories_server_type = "cx23"
      web_servers_count       = 2
      accessories_count       = 1
      domains                 = ["example.com"]
      short_domains           = ["ex.com"]
      cors_origins            = ["https://example.com"]
      storage_origin          = "bunny"
      storage_routing_tier    = "Volume"
      game_data_bucket        = true
    }
  }
}

run "create_servers" {
  command = plan

  assert {
    condition     = onepassword_item.r2_sc_data["read"].username == "mock-read-id" && onepassword_item.r2_sc_data["write"].username == "mock-write-id"
    error_message = "Each game data item should carry the key of its own access level"
  }

  assert {
    condition     = onepassword_item.r2_sc_data["read"].section[0].field[0].value == "fltyrd-sc"
    error_message = "The game data items should name the bucket"
  }

  assert {
    condition     = hcloud_server.web_server.*.name == ["fltyrd-default-web-1", "fltyrd-default-web-2"]
    error_message = "Server name is not correct"
  }

  assert {
    condition     = hcloud_server.web_server.*.server_type == ["cx33", "cx23"]
    error_message = "Each web server should take its own entry in web_server_types"
  }

  assert {
    condition     = hcloud_server.accessory_server[0].server_type == "cx23"
    error_message = "The accessories server should take accessories_server_type"
  }

  assert {
    condition     = alltrue(concat(hcloud_server.web_server.*.keep_disk, hcloud_server.accessory_server.*.keep_disk))
    error_message = "A rescale must keep the disk so the type can be lowered again"
  }

  assert {
    condition     = hcloud_load_balancer.web_load_balancer[0].name != null
    error_message = "Load balancer was not created"
  }

  assert {
    condition     = can(regex("web-1", data.cloudinit_config.web_server_config[0].part[0].content))
    error_message = "Cloud-init config for fltyrd-web-1 is not correct"
  }

  assert {
    condition     = can(regex("web-2", data.cloudinit_config.web_server_config[1].part[0].content))
    error_message = "Cloud-init config for fltyrd-web-2 is not correct"
  }

  assert {
    condition     = bunnynet_pullzone.storage.origin.type == "StorageZone"
    error_message = "The storage pull zone should pull from the uploads storage zone when storage_origin is bunny"
  }

  assert {
    condition     = bunnynet_pullzone.storage.routing.tier == "Volume"
    error_message = "The storage pull zone should take storage_routing_tier"
  }
}

run "rejects_a_type_list_shorter_than_the_server_count" {
  command = plan

  variables {
    env_config = {
      default = {
        web_server_types        = ["cx23"]
        accessories_server_type = "cx23"
        web_servers_count       = 2
        accessories_count       = 1
        domains                 = ["example.com"]
        short_domains           = ["ex.com"]
        cors_origins            = ["https://example.com"]
        storage_origin          = "hetzner"
      }
    }
  }

  expect_failures = [var.env_config]
}

run "rejects_an_unknown_storage_origin" {
  command = plan

  variables {
    env_config = {
      default = {
        web_server_types        = ["cx23"]
        accessories_server_type = "cx23"
        web_servers_count       = 1
        accessories_count       = 1
        domains                 = ["example.com"]
        short_domains           = ["ex.com"]
        cors_origins            = ["https://example.com"]
        storage_origin          = "r2"
      }
    }
  }

  expect_failures = [var.env_config]
}

run "rejects_an_unknown_storage_routing_tier" {
  command = plan

  variables {
    env_config = {
      default = {
        web_server_types        = ["cx23"]
        accessories_server_type = "cx23"
        web_servers_count       = 1
        accessories_count       = 1
        domains                 = ["example.com"]
        short_domains           = ["ex.com"]
        cors_origins            = ["https://example.com"]
        storage_origin          = "hetzner"
        storage_routing_tier    = "Premium"
      }
    }
  }

  expect_failures = [var.env_config]
}
