resource "bunnynet_pullzone" "cdn" {
  name = "fltyrd-${terraform.workspace}-cdn"

  origin {
    type                = "OriginUrl"
    url                 = length(local.env.domains) > 0 ? "https://${local.env.domains[0]}" : "https://${local.dns_ip}"
    forward_host_header = false
  }

  routing {
    tier = "Standard"
  }
}

resource "bunnynet_pullzone_hostname" "cdn" {
  for_each = toset(local.env.short_domains)

  pullzone    = bunnynet_pullzone.cdn.id
  name        = "cdn.${each.value}"
  tls_enabled = true
  force_ssl   = true
}

resource "bunnynet_pullzone" "storage" {
  name = "fltyrd-${terraform.workspace}-storage"

  origin {
    type                = "OriginUrl"
    url                 = "https://fsn1.your-objectstorage.com/fltyrd-${terraform.workspace}-storage"
    forward_host_header = false
  }

  routing {
    tier = "Standard"
  }

  cors_enabled = true
}

resource "bunnynet_pullzone_hostname" "storage" {
  for_each = toset(local.env.short_domains)

  pullzone    = bunnynet_pullzone.storage.id
  name        = "storage.${each.value}"
  tls_enabled = true
  force_ssl   = true
}

resource "bunnynet_pullzone_edgerule" "storage_cors" {
  enabled     = true
  pullzone    = bunnynet_pullzone.storage.id
  description = "Add CORS header to all responses (Active Storage keys have no file extension)"

  actions = [
    {
      type       = "SetResponseHeader"
      parameter1 = "Access-Control-Allow-Origin"
      parameter2 = "*"
      parameter3 = null
    }
  ]

  match_type = "MatchAny"
  triggers = [
    {
      type       = "Url"
      match_type = "MatchAny"
      patterns   = ["*"]
      parameter1 = null
      parameter2 = null
    }
  ]
}
