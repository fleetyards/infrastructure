data "cloudinit_config" "web_server_config" {
  count         = local.env.web_servers_count
  gzip          = true
  base64_encode = true

  # Base system configuration
  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloudinit/base.yml", {
      hostname              = local.env.web_servers_count > 1 ? "web-${count.index + 1}" : "web"
      username              = var.username
      github_username       = var.github_username
      deploy_ssh_public_key = local.deploy_ssh_public_key
    })
  }

  # Web-specific configuration
  part {
    content_type = "text/cloud-config"
    content      = file("${path.module}/cloudinit/web.yml")
    merge_type   = "list(append)+dict(no_replace,recurse_list)+str()"
  }
}

data "cloudinit_config" "accessories_config" {
  gzip          = false
  base64_encode = false
  count         = local.env.accessories_count
  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloudinit/base.yml", {
      hostname              = local.env.accessories_count > 1 ? "accessories-${count.index + 1}" : "accessories"
      username              = var.username
      github_username       = var.github_username
      deploy_ssh_public_key = local.deploy_ssh_public_key
    })
  }

  part {
    content_type = "text/cloud-config"
    content = templatefile("${path.module}/cloudinit/accessories.yml", {
      appsignal_push_api_key = data.onepassword_item.appsignal.credential
      appsignal_app_name     = "Fleetyards"
      appsignal_app_env      = terraform.workspace == "live" ? "production" : "staging"
    })
    merge_type = "list(append)+dict(recurse_array)+str()"
  }
}
