# Off-provider copy of the database backups: the servers and the Hetzner
# backups bucket share one provider, so an account or region incident there
# would take both.
module "r2_backups" {
  source = "./modules/r2_backups"

  account_id = data.onepassword_item.cloudflare.username
  name       = "fltyrd-${terraform.workspace}-backups"

  # Shorter than the backup container's BACKUP_KEEP_DAYS (7), which prunes
  # older dumps itself; a lock that outlasts it makes every prune fail.
  lock_days = 6

  expire_days = 30
}

# Stage and live load the game data from one bucket, so it belongs to live.
module "r2_sc_data" {
  source = "./modules/r2_bucket"
  count  = local.env.game_data_bucket ? 1 : 0

  account_id = data.onepassword_item.cloudflare.username
  name       = "fltyrd-sc"
}
