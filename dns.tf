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

# --- Legacy CDN CNAME (DigitalOcean Spaces, fleetyards.net only) ---

resource "hcloud_zone_rrset" "cdn_legacy" {
  for_each = var.manage_dns && terraform.workspace == "live" ? toset(local.env.domains) : toset([])

  zone = hcloud_zone.zone[each.value].name
  type = "CNAME"
  name = "cdn"
  ttl  = 600
  records = [
    { value = "fleetyards.fra1.cdn.digitaloceanspaces.com" }
  ]
}

# --- Email records (per-workspace) ---

locals {
  email_config = {
    live = {
      mx_records = [{ value = "1 smtp.google.com" }]
      cnames = {
        email = "eu.mailgun.org"
        pm    = "pm.mtasv.net"
      }
      postmark_dkim_selector = "20220207145011pm"
      postmark_dkim_key      = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCBZ1omiKMon6mNlzGAZDkoCMC4i/ghbe9Mg89Igkkesy85xNGvj/ff4s5AcahQAxsdAjZ+Oo+cXa0UlECQ/5ZsqQRKka5/UJRpoMypfPPitIcv7UzBYfnVcNNyFel3MZItAPxPM0s4sLFoQ1DFQiIlMhbnruREIMpCrSs4myqiUwIDAQAB"
      txt_records = [
        "\"google-site-verification=-QZHCDKtqEnhuNP20p87uH86OVAQtwbSOVSw8FpDySk\"",
        "\"google-site-verification=UmogpbAAHEdM2L5oDtJ2LWlhNjjNwowlK8JU19kj_w8\"",
      ]
    }
    stage = {
      mx_records = null
      cnames = {
        pm-bounces = "pm.mtasv.net"
      }
      postmark_dkim_selector = "20260331142839pm"
      postmark_dkim_key      = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDYP3C+wLr59oHiaJ8rIKJsVhdlLQhNrq3gNfcbLQf4c6rXQgVTQlbcCGNYMknh6f6rR2tzbABf3HMbfCy0WRMRTCmyJWSADZsUyO2v8U3C1iaEwunYvuH1BOnW+URsTlbCJKLgCAf1DpuHHJqxZ52wUQuCsz1F05WdIueg7Hb8UwIDAQAB"
      txt_records = null
    }
  }

  current_email = lookup(local.email_config, terraform.workspace, local.email_config["stage"])
}

resource "hcloud_zone_rrset" "mx" {
  for_each = var.manage_dns && local.current_email.mx_records != null ? toset(local.env.domains) : toset([])

  zone    = hcloud_zone.zone[each.value].name
  type    = "MX"
  name    = "@"
  ttl     = 3600
  records = coalesce(local.current_email.mx_records, [{ value = "unused" }])
}

resource "hcloud_zone_rrset" "email_cname" {
  for_each = var.manage_dns ? {
    for name, target in local.current_email.cnames :
    name => { domain = local.env.domains[0], name = name, target = target }
  } : {}

  zone = hcloud_zone.zone[each.value.domain].name
  type = "CNAME"
  name = each.value.name
  ttl  = 600
  records = [
    { value = each.value.target }
  ]
}

# --- DKIM records ---

resource "hcloud_zone_rrset" "postmark_dkim" {
  for_each = var.manage_dns ? toset(local.env.domains) : toset([])

  zone = hcloud_zone.zone[each.value].name
  type = "TXT"
  name = "${local.current_email.postmark_dkim_selector}._domainkey"
  ttl  = 600
  records = [
    { value = "\"k=rsa;p=${local.current_email.postmark_dkim_key}\"" }
  ]
}

# --- TXT records ---

resource "hcloud_zone_rrset" "txt" {
  for_each = var.manage_dns && local.current_email.txt_records != null ? toset(local.env.domains) : toset([])

  zone    = hcloud_zone.zone[each.value].name
  type    = "TXT"
  name    = "@"
  ttl     = 600
  records = [for v in coalesce(local.current_email.txt_records, ["unused"]) : { value = v }]
}
