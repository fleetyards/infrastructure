locals {
  env = var.env_config[terraform.workspace]

  deploy_ssh_public_key = data.onepassword_item.ssh[terraform.workspace == "live" ? "deploy_public_key_live" : "deploy_public_key_stage"].value

  web_server_ips = [
    for i in range(local.env.web_servers_count) :
    "10.0.0.${i + 2}"
  ]
  accessories_server_ips = [
    for i in range(local.env.accessories_count) :
    "10.0.0.${i + local.env.web_servers_count + 2}"
  ]
}
