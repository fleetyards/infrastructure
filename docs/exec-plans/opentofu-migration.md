# OpenTofu Migration Evaluation

## Status: On Hold

## What is OpenTofu?

OpenTofu is an open-source fork of Terraform, created by the Linux Foundation after HashiCorp switched Terraform from MPL to the BSL (Business Source License) in August 2023. It aims to be a drop-in replacement.

## Pros of Migrating

- **Truly open-source (MPL 2.0)** - no licensing risk if HashiCorp further restricts the BSL
- **Community-governed** under the Linux Foundation, not a single company
- **Drop-in compatible** - existing `.tf` files, state, and providers (hcloud, dnsimple, cloudinit) all work as-is
- **State encryption** built-in (Terraform doesn't have this natively)
- **Growing ecosystem** - major cloud providers and tooling (Spacelift, env0, Scalr) support it

## Cons of Migrating

- **Feature lag** - OpenTofu tracks Terraform but new features (like `moved` blocks, `import` blocks) sometimes land later
- **Smaller ecosystem** - fewer tutorials, Stack Overflow answers, and blog posts; most docs still reference `terraform`
- **Provider compatibility risk** - some future HashiCorp providers could theoretically become BSL-only (hasn't happened yet for community providers like hcloud/dnsimple)
- **Terraform Cloud/HCP incompatible** - though we use an S3 backend so this doesn't apply
- **Version gap** - we require Terraform `>= 1.12.0`; OpenTofu tracks ~1.6-1.8 feature parity, so we'd need to verify all features we depend on are available

## Current Assessment

**Recommendation: Do not migrate at this time.**

1. Our infra is simple and clean - Hetzner servers, load balancer, firewalls, DNS records, S3 backend. Nothing here requires cutting-edge features or Terraform Cloud.
2. The BSL license does not affect us - it only restricts companies building competing infrastructure-as-a-service products. For managing our own infra, Terraform is free to use.
3. We require `>= 1.12.0` - OpenTofu's latest stable is around 1.9.x (forked from Terraform 1.6). Features we depend on may not be available yet.

## When to Revisit

- HashiCorp makes licensing changes that affect our use case
- OpenTofu reaches feature parity with our required Terraform version
- We want built-in state encryption without third-party tooling

## Migration Steps (for future reference)

If we decide to migrate, the process is straightforward:

1. Install OpenTofu (`tofu` CLI)
2. Verify provider compatibility (hcloud, dnsimple, cloudinit)
3. Run `tofu init` against existing state (same S3 backend, same state files)
4. Run `tofu plan` and confirm no changes
5. Update CI pipelines to use `tofu` instead of `terraform`
6. Update `required_version` in `versions.tf` to match OpenTofu versioning
