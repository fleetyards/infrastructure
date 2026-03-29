mock_provider "hcloud" {}
mock_provider "dnsimple" {}
mock_provider "aws" {}
mock_provider "bunnynet" {}
mock_provider "onepassword" {}

variables {
  env_config = {
    default = {
      server_type       = "cx23"
      web_servers_count = 2
      accessories_count = 1
      domains           = ["example.com"]
      short_domains     = ["ex.com"]
      cors_origins      = ["https://example.com"]
    }
  }
}

run "create_servers" {
  command = plan

  assert {
    condition = hcloud_server.web_server.*.name == ["fltyrd-default-web-1", "fltyrd-default-web-2"]
    error_message = "Server name is not correct"
  }

  assert {
    condition = hcloud_load_balancer.web_load_balancer[0].name != null
    error_message = "Load balancer was not created"
  }

  assert {
    condition = can(regex("web-1", data.cloudinit_config.web_server_config[0].part[0].content))
    error_message = "Cloud-init config for fltyrd-web-1 is not correct"
  }

  assert {
    condition = can(regex("web-2", data.cloudinit_config.web_server_config[1].part[0].content))
    error_message = "Cloud-init config for fltyrd-web-2 is not correct"
  }
}
