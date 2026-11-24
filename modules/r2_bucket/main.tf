terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

variable "account_id" {
  description = "Cloudflare account that owns the bucket."
  type        = string
}

variable "name" {
  description = "Bucket name, also the prefix of its access tokens' names."
  type        = string
}

locals {
  access = {
    read  = "Workers R2 Storage Bucket Item Read"
    write = "Workers R2 Storage Bucket Item Write"
  }
}

resource "cloudflare_r2_bucket" "this" {
  account_id = var.account_id
  name       = var.name
  location   = "eeur"

  lifecycle {
    prevent_destroy = true
  }
}

data "cloudflare_account_api_token_permission_groups_list" "this" {
  for_each = local.access

  account_id = var.account_id
  name       = replace(each.value, " ", "%20")
  scope      = "com.cloudflare.edge.r2.bucket"

  lifecycle {
    postcondition {
      condition     = length(self.result) == 1
      error_message = "Expected exactly one \"${each.value}\" permission group, found ${length(self.result)}."
    }
  }
}

resource "cloudflare_account_token" "this" {
  for_each = local.access

  account_id = var.account_id
  name       = "${var.name}-${each.key}"

  policies = [{
    effect            = "allow"
    permission_groups = [{ id = one(data.cloudflare_account_api_token_permission_groups_list.this[each.key].result[*].id) }]
    resources = jsonencode({
      "com.cloudflare.edge.r2.bucket.${var.account_id}_default_${cloudflare_r2_bucket.this.name}" = "*"
    })
  }]
}

output "bucket" {
  value = cloudflare_r2_bucket.this.name
}

output "endpoint" {
  value = "https://${var.account_id}.r2.cloudflarestorage.com"
}

# R2's S3 credentials are derived from an account token: the access key ID is
# the token's ID and the secret is the SHA-256 of its value.
output "credentials" {
  value = {
    for access, token in cloudflare_account_token.this : access => {
      access_key_id     = token.id
      secret_access_key = sha256(token.value)
    }
  }
  sensitive = true
}
