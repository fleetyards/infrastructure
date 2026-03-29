# 1Password CLI + Terraform Provider for Secrets Management

## Status: Implemented (pending CI secret `OP_SERVICE_ACCOUNT_TOKEN`)

## Context

Secrets were previously stored in git-crypt encrypted `.tfvars` files for local use, and duplicated in GitHub Secrets for CI. This meant rotating a secret required updating both places.

All secrets are now consolidated into 1Password via the Terraform `onepassword` provider, accessed at plan/apply time both locally and in CI.

## 1Password Vault Layout

Vault: **Fleetyards**

| Item | Category | Fields used |
|---|---|---|
| `HCLOUD_STAGE` | API Credential | `credential` (API token) |
| `HCLOUD_LIVE` | API Credential | `credential` (API token) |
| `SSH Config` | Login | `username` (SSH key name), section fields for deploy keys |
| `DNSimple` | API Credential | `credential` (token), `username` (account ID) |
| `BunnyCDN` | API Credential | `credential` (API key) |

Deploy SSH public keys are stored as fields on the SSH Config item, selected by workspace (`deploy_public_key_live` / `deploy_public_key_stage`).

## Pros

- **Single source of truth** — secrets live in 1Password, not scattered across `.tfvars` files and GitHub Secrets
- **No encrypted files in git** — removes the need for git-crypt entirely
- **No encryption key management** — no GPG keys to rotate, share, or onboard new team members with
- **Audit trail** — 1Password logs access to secrets
- **Simple rotation** — update in 1Password, next `terraform apply` picks it up
- **Works locally and in CI** — same provider, same vault, same workflow
- **Terraform-native** — data sources integrate cleanly into HCL

## Cons

- **External dependency at plan/apply time** — if 1Password is down, Terraform cannot run
- **Authentication friction** — requires 1Password desktop app or `op signin` before each session
- **Cost** — requires 1Password Teams/Business plan for service accounts (CI)
- **Provider maturity** — less mature than e.g. HashiCorp Vault provider
- **Bootstrap problem in CI** — still need one secret (`OP_SERVICE_ACCOUNT_TOKEN`) in GitHub Secrets
- **S3 backend limitation** — backend initializes before providers, so AWS creds cannot use the Terraform provider

## How It Works

### Locally

- 1Password desktop app must be running (authenticates the `onepassword` provider)
- AWS S3 backend credentials are loaded from a gitignored `.env` file (unchanged)
- `terraform plan` / `terraform apply` fetches all other secrets from 1Password at runtime

### In CI (GitHub Actions)

- `OP_SERVICE_ACCOUNT_TOKEN` GitHub Secret authenticates the `onepassword` provider
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` remain in GitHub Secrets for the S3 backend
- All other secrets (`TF_VAR_*`, `DNSIMPLE_*`) have been removed from GitHub Secrets

### Key Files

| File | Role |
|---|---|
| `secrets.tf` | `onepassword` provider + vault/item data sources |
| `providers.tf` | Providers consume secrets via `data.onepassword_item.*.credential` |
| `locals.tf` | Workspace-aware deploy SSH key selection |
| `cloud.tf` | SSH key name from `data.onepassword_item.ssh.username` |
| `data.tf` | Deploy SSH public key from `local.deploy_ssh_public_key` |

### Non-Secret Variables

- `github_username` — hardcoded default `"mortik"` in `variables.tf` (same across all environments)
- `region`, `operating_system`, `env_config`, `username` — unchanged, non-sensitive

## Remaining Steps

1. Create a **1Password Service Account** with read access to the Fleetyards vault
2. Add `OP_SERVICE_ACCOUNT_TOKEN` to GitHub repo secrets
3. Remove old GitHub Secrets that are no longer needed (`HETZNER_API_KEY`, `HETZNER_API_KEY_STAGE`, `HETZNER_SSH_KEY_NAME`, `USERNAME`, `DEPLOY_SSH_PUBLIC_KEY`, `DNSIMPLE_TOKEN`, `DNSIMPLE_ACCOUNT`, `BUNNY_API_KEY`)

## Verification

1. `terraform init -upgrade` to download the onepassword provider
2. `terraform test` — verify tests pass with mocked onepassword provider
3. `terraform workspace select stage && terraform plan` — verify secrets resolve
4. `terraform workspace select live && terraform plan` — verify secrets resolve
5. Push to branch, open PR, verify CI test + plan succeeds with `OP_SERVICE_ACCOUNT_TOKEN`

## Files Changed

| File | Action |
|---|---|
| `versions.tf` | Added `onepassword` provider |
| `secrets.tf` | **New** — 1P provider, vault, and item data sources |
| `providers.tf` | hcloud, dnsimple, bunnynet read from 1P `.credential` |
| `variables.tf` | Removed `hetzner_api_key`, `ssh_key_name`, `deploy_ssh_public_key`, `bunny_api_key`; added `github_username` default |
| `locals.tf` | Added `deploy_ssh_public_key` local with workspace-aware 1P lookup |
| `cloud.tf` | `var.ssh_key_name` → `data.onepassword_item.ssh.username` |
| `data.tf` | `var.deploy_ssh_public_key` → `local.deploy_ssh_public_key` |
| `terraform.tfvars` | **Deleted** |
| `stage.tfvars` | **Deleted** |
| `.gitignore` | `*.tfvars` now ignored |
| `.github/workflows/terraform-deploy.yml` | Replaced `TF_VAR_*`/`DNSIMPLE_*` with `OP_SERVICE_ACCOUNT_TOKEN` |
| `.github/workflows/terraform-test.yml` | Same CI cleanup |
| `tests/single_server.tftest.hcl` | Added `mock_provider "onepassword" {}`, removed secret var overrides |
| `tests/multiple_servers.tftest.hcl` | Added `mock_provider "onepassword" {}`, removed secret var overrides |
| `AGENTS.md` | Updated "Sensitive Data" section |
