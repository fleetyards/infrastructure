locals {
  env_config = {
    default = {
      server_type       = "cx23"
      web_servers_count = 1
      accessories_count = 1
    }
    stage = {
      server_type       = "cx23"
      web_servers_count = 1
      accessories_count = 1
    }
    live = {
      server_type       = "cx23"
      web_servers_count = 1
      accessories_count = 1
    }
  }

  env = local.env_config[terraform.workspace]

  web_server_ips = [
    for i in range(local.env.web_servers_count) :
    "10.0.0.${i + 2}"
  ]
  accessories_server_ips = [
    for i in range(local.env.accessories_count) :
    "10.0.0.${i + local.env.web_servers_count + 2}"
  ]
}
