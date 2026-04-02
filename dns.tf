locals {
  dns_subdomains = ["", "www", "api", "admin", "docs"]

  dns_ip = var.manage_dns ? (
    local.env.web_servers_count > 1
    ? hcloud_load_balancer.web_load_balancer[0].ipv4
    : hcloud_server.web_server[0].ipv4_address
  ) : null

  all_domains = concat(local.env.domains, local.env.short_domains)

  dns_records = flatten([
    for domain in local.env.domains : [
      for subdomain in local.dns_subdomains : {
        domain = domain
        name   = subdomain == "" ? "@" : subdomain
      }
    ]
  ])

  dns_short_records = [
    for domain in local.env.short_domains : {
      domain = domain
      name   = "@"
    }
  ]

  dns_all_records = concat(local.dns_records, local.dns_short_records)

  dns_cdn_records = flatten([
    for domain in local.env.short_domains : [
      {
        domain     = domain
        name       = "cdn"
        cdn_domain = "${bunnynet_pullzone.cdn.name}.b-cdn.net"
      },
      {
        domain     = domain
        name       = "storage"
        cdn_domain = "${bunnynet_pullzone.storage.name}.b-cdn.net"
      },
    ]
  ])
}

# --- Hetzner DNS zones ---

resource "hcloud_zone" "zone" {
  for_each = toset(local.all_domains)
  name     = each.value
  mode     = "primary"
}

# --- A records (web servers / load balancer) ---

resource "hcloud_zone_rrset" "web" {
  for_each = var.manage_dns ? {
    for record in local.dns_all_records :
    "${record.domain}/${record.name}" => record
  } : {}

  zone = hcloud_zone.zone[each.value.domain].name
  type = "A"
  name = each.value.name
  ttl  = 600
  records = [
    { value = local.dns_ip }
  ]
}

# --- CDN CNAME records ---

resource "hcloud_zone_rrset" "cdn" {
  for_each = var.manage_dns ? {
    for record in local.dns_cdn_records :
    "${record.domain}/${record.name}" => record
  } : {}

  zone = hcloud_zone.zone[each.value.domain].name
  type = "CNAME"
  name = each.value.name
  ttl  = 600
  records = [
    { value = each.value.cdn_domain }
  ]
}

# --- Email records (fleetyards.net only) ---

resource "hcloud_zone_rrset" "mx" {
  for_each = var.manage_dns ? toset(local.env.domains) : toset([])

  zone = hcloud_zone.zone[each.value].name
  type = "MX"
  name = "@"
  ttl  = 3600
  records = [
    { value = "1 smtp.google.com" }
  ]
}

resource "hcloud_zone_rrset" "email_cname" {
  for_each = var.manage_dns ? toset(local.env.domains) : toset([])

  zone = hcloud_zone.zone[each.value].name
  type = "CNAME"
  name = "email"
  ttl  = 3600
  records = [
    { value = "eu.mailgun.org" }
  ]
}

resource "hcloud_zone_rrset" "pm_cname" {
  for_each = var.manage_dns ? toset(local.env.domains) : toset([])

  zone = hcloud_zone.zone[each.value].name
  type = "CNAME"
  name = "pm"
  ttl  = 600
  records = [
    { value = "pm.mtasv.net" }
  ]
}

# --- DKIM records ---

resource "hcloud_zone_rrset" "postmark_dkim" {
  for_each = var.manage_dns ? toset(local.env.domains) : toset([])

  zone = hcloud_zone.zone[each.value].name
  type = "TXT"
  name = "20220207145011pm._domainkey"
  ttl  = 600
  records = [
    { value = "\"k=rsa;p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCBZ1omiKMon6mNlzGAZDkoCMC4i/ghbe9Mg89Igkkesy85xNGvj/ff4s5AcahQAxsdAjZ+Oo+cXa0UlECQ/5ZsqQRKka5/UJRpoMypfPPitIcv7UzBYfnVcNNyFel3MZItAPxPM0s4sLFoQ1DFQiIlMhbnruREIMpCrSs4myqiUwIDAQAB\"" }
  ]
}

# --- TXT records ---

resource "hcloud_zone_rrset" "google_site_verification" {
  for_each = var.manage_dns ? toset(local.env.domains) : toset([])

  zone = hcloud_zone.zone[each.value].name
  type = "TXT"
  name = "@"
  ttl  = 600
  records = [
    { value = "\"google-site-verification=-QZHCDKtqEnhuNP20p87uH86OVAQtwbSOVSw8FpDySk\"" },
    { value = "\"google-site-verification=UmogpbAAHEdM2L5oDtJ2LWlhNjjNwowlK8JU19kj_w8\"" },
  ]
}
