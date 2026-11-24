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

data "onepassword_item" "bunny" {
  vault = data.onepassword_vault.infra.uuid
  title = "BunnyCDN"
}

data "onepassword_item" "cloudflare" {
  vault = data.onepassword_vault.infra.uuid
  title = "Cloudflare"
}

data "onepassword_item" "appsignal" {
  vault = data.onepassword_vault.infra.uuid
  title = "APPSIGNAL"
}

resource "onepassword_item" "bunny_storage" {
  vault    = data.onepassword_vault.infra.uuid
  title    = "BUNNY_STORAGE_${upper(terraform.workspace)}"
  category = "password"
  password = bunnynet_storage_zone.assets.password

  section {
    label = "config"

    field {
      label = "zone_name"
      value = bunnynet_storage_zone.assets.name
    }

    field {
      label = "endpoint"
      value = "https://storage.bunnycdn.com"
    }
  }
}

resource "onepassword_item" "bunny_uploads" {
  vault    = data.onepassword_vault.infra.uuid
  title    = "BUNNY_UPLOADS_${upper(terraform.workspace)}"
  category = "password"
  password = bunnynet_storage_zone.uploads.password

  section {
    label = "config"

    field {
      label = "zone_name"
      value = bunnynet_storage_zone.uploads.name
    }

    field {
      label = "endpoint"
      value = "https://${bunnynet_storage_zone.uploads.hostname_s3}"
    }

    field {
      label = "region"
      value = lower(bunnynet_storage_zone.uploads.region)
    }
  }
}

resource "onepassword_item" "r2_backups" {
  vault    = data.onepassword_vault.infra.uuid
  title    = "R2_BACKUPS_${upper(terraform.workspace)}"
  category = "login"
  username = module.r2_backups.access_key_id
  password = module.r2_backups.secret_access_key

  section {
    label = "config"

    field {
      label = "bucket"
      value = module.r2_backups.bucket
    }

    field {
      label = "endpoint"
      value = module.r2_backups.endpoint
    }

    field {
      label = "region"
      value = "auto"
    }
  }
}
