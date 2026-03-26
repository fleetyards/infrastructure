# FleetYards Infrastructure

Terraform-managed infrastructure for FleetYards on Hetzner Cloud with DNS via DNSimple.

## Project Overview

This repo provisions Hetzner Cloud servers (web + accessories), networking, firewalls, load balancers, and DNS records. Servers are configured via cloud-init and deployed with Kamal. State is stored in an S3-compatible backend (Hetzner Object Storage).

## Architecture

- **Web servers**: Public-facing, ports 80/443/22 open, run the application
- **Accessory servers**: Private, only reachable via ProxyJump through web servers, run databases/caches
- **Load balancer**: Created automatically when `web_servers_count > 1`
- **DNS**: Managed via DNSimple (A records for root, www, api, admin, docs subdomains + short domains)
- **Workspaces**: `stage` (fleetyards.dev) and `live` (fleetyards.net) — workspace-driven config via `env_config` in variables.tf

## Key Files

| File | Purpose |
|---|---|
| `cloud.tf` | Core resources: servers, network, firewalls, load balancer |
| `dns.tf` | DNSimple DNS records |
| `data.tf` | Cloud-init data sources for server provisioning |
| `variables.tf` | Input variables and per-environment config (`env_config`) |
| `locals.tf` | Computed values (IP assignments) |
| `versions.tf` | Terraform version constraints, backend config, provider versions |
| `providers.tf` | Provider configuration (Hetzner, DNSimple) |
| `outputs.tf` | Server IPs and SSH config output |
| `cloudinit/` | Cloud-init templates (base.yml, web.yml, accessories.yml) |
| `tests/` | Terraform native tests (`.tftest.hcl`) |

## Commands

```bash
# Initialize
terraform init

# Validate configuration
terraform validate

# Run tests
terraform test

# Plan changes (select workspace first)
terraform workspace select stage
terraform plan

# Apply changes
terraform apply

# Format all .tf files
terraform fmt
```

## CI/CD Pipeline

- **Test** (`.github/workflows/terraform-test.yml`): Runs `terraform validate` and `terraform test` on push to main and PRs
- **Deploy** (`.github/workflows/terraform-deploy.yml`):
  - **Stage**: Auto-deploys after successful test on main
  - **Live**: Manual dispatch only, with destructive change detection — blocks if plan contains any deletes or replacements

## Working with This Repo

### Sensitive Data

- `terraform.tfvars` is encrypted with **git-crypt** and committed (not gitignored)
- `.tfstate` files are also git-crypt encrypted
- Never commit unencrypted secrets — variables marked `sensitive = true` in variables.tf
- CI uses `TF_VAR_*` env vars and GitHub Secrets, and removes the encrypted tfvars before init

### Conventions

- Resource naming: `fltyrd-{workspace}-{role}[-{index}]` (e.g., `fltyrd-live-web-1`)
- Private network: `10.0.0.0/16`, subnet `10.0.0.0/24`
- Web server IPs start at `10.0.0.2`, accessory IPs follow sequentially
- Server labels control firewall assignment (`ssh=yes`, `http=yes/no`, `env={workspace}`)

### Safety

- The `live` deploy pipeline blocks destructive changes (deletes/replacements) automatically
- `user_data` changes are ignored via lifecycle rules (servers won't be recreated for cloud-init changes)
- Always run `terraform plan` before `terraform apply` locally
- When modifying `live` workspace resources, prefer the CI pipeline over local applies
- Never run `terraform destroy` on `live` workspace without explicit confirmation
- Never run `terraform apply` without reviewing the plan first

### Testing

- Tests live in `tests/*.tftest.hcl`
- `single_server.tftest.hcl` — validates single web + accessories setup
- `multiple_servers.tftest.hcl` — validates multi-server + load balancer setup
- Tests use mock providers to avoid requiring real API credentials
- Always run `terraform test` after making changes
- Always run `terraform validate` before committing
- Always run `terraform fmt` before committing

### Adding Resources

- Follow existing patterns in `cloud.tf` for Hetzner resources
- Use workspace-aware naming: `"fltyrd-${terraform.workspace}-{name}"`
- Add relevant labels for firewall rules
- If adding new providers, pin versions in `versions.tf`
- Add test coverage in `tests/` for new resources
