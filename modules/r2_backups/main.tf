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
  description = "Bucket name, also used for the access token."
  type        = string
}

variable "lock_days" {
  description = "How long a backup cannot be deleted or overwritten."
  type        = number
}

variable "expire_days" {
  description = "Age at which R2 deletes a backup itself, in case the uploader's own prune never reaches the bucket."
  type        = number

  validation {
    condition     = var.expire_days > var.lock_days
    error_message = "expire_days must be longer than lock_days, or R2 cannot delete what the lock still holds."
  }
}

resource "cloudflare_r2_bucket" "backups" {
  account_id = var.account_id
  name       = var.name
  location   = "eeur"

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_r2_bucket_lock" "backups" {
  account_id  = var.account_id
  bucket_name = cloudflare_r2_bucket.backups.name

  rules = [{
    id      = "keep-recent-backups"
    enabled = true
    condition = {
      type            = "Age"
      max_age_seconds = var.lock_days * 24 * 60 * 60
    }
  }]
}

resource "cloudflare_r2_bucket_lifecycle" "backups" {
  account_id  = var.account_id
  bucket_name = cloudflare_r2_bucket.backups.name

  rules = [{
    id         = "expire-old-backups"
    enabled    = true
    conditions = { prefix = "" }
    delete_objects_transition = {
      condition = {
        type    = "Age"
        max_age = var.expire_days * 24 * 60 * 60
      }
    }
  }]
}

data "cloudflare_account_api_token_permission_groups_list" "r2_bucket_item_write" {
  account_id = var.account_id
  name       = "Workers%20R2%20Storage%20Bucket%20Item%20Write"
  scope      = "com.cloudflare.edge.r2.bucket"

  lifecycle {
    postcondition {
      condition     = length(self.result) == 1
      error_message = "Expected exactly one \"Workers R2 Storage Bucket Item Write\" permission group, found ${length(self.result)}."
    }
  }
}

resource "cloudflare_account_token" "backups" {
  account_id = var.account_id
  name       = var.name

  policies = [{
    effect            = "allow"
    permission_groups = [{ id = one(data.cloudflare_account_api_token_permission_groups_list.r2_bucket_item_write.result[*].id) }]
    resources = jsonencode({
      "com.cloudflare.edge.r2.bucket.${var.account_id}_default_${cloudflare_r2_bucket.backups.name}" = "*"
    })
  }]
}

output "bucket" {
  value = cloudflare_r2_bucket.backups.name
}

output "endpoint" {
  value = "https://${var.account_id}.r2.cloudflarestorage.com"
}

# R2's S3 credentials are derived from an account token: the access key ID is
# the token's ID and the secret is the SHA-256 of its value.
output "access_key_id" {
  value = cloudflare_account_token.backups.id
}

output "secret_access_key" {
  value     = sha256(cloudflare_account_token.backups.value)
  sensitive = true
}
