resource "bunnynet_storage_zone" "assets" {
  name      = "fltyrd-${terraform.workspace}-assets"
  region    = "DE"
  zone_tier = "Standard"

  replication_regions = ["NY", "LA", "SG", "SYD", "UK", "SE", "BR", "JH"]
}

resource "bunnynet_pullzone" "cdn" {
  name = "fltyrd-${terraform.workspace}-cdn"

  origin {
    type                = var.cdn_use_storage_origin ? "StorageZone" : "OriginUrl"
    url                 = var.cdn_use_storage_origin ? null : (length(local.env.domains) > 0 ? "https://${local.env.domains[0]}" : "https://${local.dns_ip}")
    storagezone         = var.cdn_use_storage_origin ? bunnynet_storage_zone.assets.id : null
    forward_host_header = var.cdn_use_storage_origin ? null : false
  }

  routing {
    tier = "Standard"
  }
}

resource "bunnynet_pullzone_hostname" "cdn" {
  for_each = var.manage_dns ? toset(local.env.short_domains) : toset([])

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
  for_each = var.manage_dns ? toset(local.env.short_domains) : toset([])

  pullzone    = bunnynet_pullzone.storage.id
  name        = "storage.${each.value}"
  tls_enabled = true
  force_ssl   = true
}

resource "bunnynet_pullzone_edgerule" "cdn_vite_assets_cache" {
  enabled     = true
  pullzone    = bunnynet_pullzone.cdn.id
  description = "Immutable cache for Vite hashed assets"

  actions = [
    {
      type       = "OverrideCacheTime"
      parameter1 = "31536000"
      parameter2 = null
      parameter3 = null
    },
    {
      type       = "SetResponseHeader"
      parameter1 = "Cache-Control"
      parameter2 = "public, max-age=31536000, immutable"
      parameter3 = null
    }
  ]

  match_type = "MatchAny"
  triggers = [
    {
      type       = "Url"
      match_type = "MatchAny"
      patterns   = ["*/vite/assets/*"]
      parameter1 = null
      parameter2 = null
    }
  ]
}

resource "bunnynet_pullzone_edgerule" "cdn_no_cache_errors" {
  enabled     = true
  pullzone    = bunnynet_pullzone.cdn.id
  description = "Prevent caching of error responses"

  actions = [
    {
      type       = "OverrideCacheTime"
      parameter1 = "0"
      parameter2 = null
      parameter3 = null
    }
  ]

  match_type = "MatchAny"
  triggers = [
    {
      type       = "StatusCode"
      match_type = "MatchAny"
      patterns   = ["404", "500", "502", "503", "504"]
      parameter1 = null
      parameter2 = null
    }
  ]
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
