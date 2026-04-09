provider "onepassword" {}

data "onepassword_vault" "infra" {
  name = "Fleetyards"
}

data "onepassword_item" "hetzner" {
  vault = data.onepassword_vault.infra.uuid
  title = terraform.workspace == "live" ? "HCLOUD_LIVE" : "HCLOUD_STAGE"
}

data "onepassword_item" "ssh" {
  vault = data.onepassword_vault.infra.uuid
  title = "SSH Config"
}

data "onepassword_item" "deploy_key" {
  vault = data.onepassword_vault.infra.uuid
  title = terraform.workspace == "live" ? "Deploy Key Live" : "Deploy Key Stage"
}

data "onepassword_item" "dnsimple" {
  vault = data.onepassword_vault.infra.uuid
  title = "DNSimple"
}

data "onepassword_item" "bunny" {
  vault = data.onepassword_vault.infra.uuid
  title = "BunnyCDN"
}

data "onepassword_item" "appsignal" {
  vault = data.onepassword_vault.infra.uuid
  title = "APPSIGNAL"
}
