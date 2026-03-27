mock_provider "dnsimple" {}
mock_provider "aws" {}

variables {
  deploy_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAItest test@test"
}

run "create_servers" {
  command = plan

  assert {
    condition = hcloud_server.web_server.*.name == ["fltyrd-default-web"]
    error_message = "Server name is not correct"
  }

  assert {
    condition = hcloud_load_balancer.web_load_balancer == []
    error_message = "Load balancer was created"
  }

  assert {
    condition = can(regex("web", data.cloudinit_config.web_server_config[0].part[0].content))
    error_message = "Cloud-init config for fltyrd-web is not correct"
  }

  assert {
    condition = can(regex("accessories", data.cloudinit_config.accessories_config[0].part[0].content))
    error_message = "Cloud-init config for fltyrd-accessories is not correct"
  }
}
