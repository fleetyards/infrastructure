# Live Infrastructure Migration

## Status: Planned

## Overview

Migrate FleetYards production from the legacy single Hetzner dedicated server (Ansible-managed, traditional deployment) to the new Hetzner Cloud infrastructure (Terraform-managed, Kamal/Docker deployment).

**Legacy setup:** Single server running Rails (Puma + Sidekiq), PostgreSQL 16, Redis, OpenSearch, Memcached, Nginx. Managed via Ansible with systemd services, no containers.

**Target setup:** 2x cx32 web servers + 1x cx32 accessory server on Hetzner Cloud. Load balancer, private network, firewalls. Deployed via Kamal with Docker containers. PostgreSQL + Redis on the accessory server.

**What's changing:**
- Elixir/Phoenix apps, OpenSearch, and Memcached are dropped
- Only Rails (Puma + Sidekiq) + PostgreSQL + Redis remain
- Uploads already on object storage — no file migration needed
- Backups handled by Kamal to Hetzner storage

**Strategy:** Maintenance window with brief downtime. Estimated 20-40 minutes.

---

## Phase 0: Pre-Migration Prep (days before)

### 0.1 Lower DNS TTLs
- [ ] Reduce TTL on all live DNS records to 60s (fleetyards.net, fltyrd.net, and all subdomains)
- [ ] Wait 24-48h for old TTLs to expire before proceeding

### 0.2 Provision and verify Terraform live infrastructure
```bash
source .env
terraform workspace select live
terraform plan -var="manage_dns=false"
terraform apply -var="manage_dns=false"
```
- [ ] All servers running (web-1, web-2, accessories)
- [ ] SSH access works to all servers
- [ ] Private network connectivity between web and accessory servers confirmed
- [ ] DNS still points to old server (manage_dns=false skips DNS records)
- [ ] Load balancer healthy

### 0.3 Set up data services on accessory server
- [ ] PostgreSQL running and reachable from web servers over private network (10.0.0.x)
- [ ] Redis running and reachable from web servers over private network
- [ ] App database and database user created

### 0.4 Verify Kamal configuration
- [ ] Kamal deploy config in the app repo targets the new server IPs
- [ ] Kamal backup configuration is in place
- [ ] Test deploy to new servers succeeds (app containers start, DB connection will fail — expected)

---

## Phase 1: Dry Run on New Live Infrastructure

Since there is no legacy stage system, validate the new infrastructure before the maintenance window using the new live servers directly.

- [ ] Verify Kamal can deploy the app containers to the new web servers (they won't serve real traffic yet — DNS still points to old server)
- [ ] Create a test database on the new accessory server, load a sanitized dump or recent backup to verify the restore process works
- [ ] Confirm the app connects to PostgreSQL and Redis over the private network
- [ ] Test key user flows against the new servers directly via IP / hosts file override
- [ ] Document any issues found and adjust this plan

---

## Phase 2: Live Maintenance Window

### Step 1 — Freeze (~5 min)

1. Announce maintenance / enable maintenance page
2. Stop Rails app and Sidekiq on old server:
   ```bash
   sudo systemctl stop fleetyards-app fleetyards-worker
   ```

### Step 2 — Database Migration (~10-20 min)

3. Create final PostgreSQL dump on old server:
   ```bash
   pg_dump -Fc -U fleetyards fleetyards > /tmp/fleetyards_final.dump
   ```

4. Transfer dump to new accessory server (via web server ProxyJump since accessory has no public IP):
   ```bash
   scp -o ProxyJump=kamal@<web-1-public-ip> /tmp/fleetyards_final.dump kamal@<accessory-private-ip>:/tmp/
   ```

5. Restore on new accessory server:
   ```bash
   pg_restore -U fleetyards -d fleetyards --no-owner --no-privileges /tmp/fleetyards_final.dump
   ```

6. Redis: skip migration — caches and Sidekiq queues rebuild naturally.

### Step 3 — Deploy & Verify (~5-10 min)

7. Deploy via Kamal:
   ```bash
   kamal deploy
   ```

8. Verify:
   - [ ] Health endpoints respond on both web servers
   - [ ] Database connectivity works
   - [ ] Key user flows work (login, browse, search)
   - [ ] Sidekiq is processing jobs

### Step 4 — DNS Cutover (~5 min + propagation)

9. Update DNS to point to new load balancer / web server IPs:
   ```bash
   source .env
   terraform workspace select live
   terraform apply
   ```

10. Verify:
    - [ ] `dig fleetyards.net` resolves to new IP
    - [ ] SSL certificates issued (Kamal/Traefik handles Let's Encrypt)
    - [ ] All domains respond correctly (fleetyards.net, fltyrd.net, api, admin, docs, www variants)

### Step 5 — Post-Cutover Monitoring (~30 min)

11. Monitor:
    - [ ] Error rates in logs
    - [ ] Response times
    - [ ] Full end-to-end user flow test
    - [ ] Backups running (Kamal backup to Hetzner)

---

## Phase 3: Post-Migration

- [ ] Keep old server running (services stopped) for 1-2 weeks as fallback
- [ ] Monitor performance and error rates on new infrastructure
- [ ] Restore DNS TTLs to normal values (300s+)
- [ ] Update CI/CD secrets if server IPs changed
- [ ] Decommission old server once confident
- [ ] Archive `infrastructure-legacy` repo

---

## Rollback Plan

If critical issues arise during the maintenance window:

1. Re-point DNS back to old server IP (manual DNSimple update or revert Terraform)
2. Restart services on old server:
   ```bash
   sudo systemctl start fleetyards-app fleetyards-worker
   ```
3. Investigate root cause and retry migration later

The old server remains fully intact until explicitly decommissioned in Phase 3.
