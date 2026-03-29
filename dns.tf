locals {
  dns_subdomains = ["", "www", "api", "admin", "docs"]

  dns_ip = (
    local.env.web_servers_count > 1
    ? hcloud_load_balancer.web_load_balancer[0].ipv4
    : hcloud_server.web_server[0].ipv4_address
  )

  dns_records = flatten([
    for domain in local.env.domains : [
      for subdomain in local.dns_subdomains : {
        domain = domain
        name   = subdomain
      }
    ]
  ])

  dns_short_records = [
    for domain in local.env.short_domains : {
      domain = domain
      name   = ""
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

resource "dnsimple_zone_record" "web" {
  for_each = {
    for record in local.dns_all_records :
    "${record.domain}/${record.name}" => record
  }

  zone_name = each.value.domain
  name      = each.value.name
  type      = "A"
  value     = local.dns_ip
  ttl       = 600
}

resource "dnsimple_zone_record" "cdn" {
  for_each = {
    for record in local.dns_cdn_records :
    "${record.domain}/${record.name}" => record
  }

  zone_name = each.value.domain
  name      = each.value.name
  type      = "CNAME"
  value     = each.value.cdn_domain
  ttl       = 600
}
