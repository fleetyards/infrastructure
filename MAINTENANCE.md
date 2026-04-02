# Server Maintenance

This runbook covers maintenance procedures for the FleetYards infrastructure. All servers run Ubuntu 24.04 on Hetzner Cloud, managed by Terraform and deployed with Kamal.

## Server Access

Web servers are accessible directly via SSH. Accessory servers require a ProxyJump through a web server. Run `terraform output` to get the SSH config for your `~/.ssh/config`.

```bash
# Web server
ssh kamal@<web-server-ip>

# Accessory server (via ProxyJump)
ssh -J kamal@<web-server-ip> kamal@<accessory-server-ip>
```

## Automated Security Patches

All servers run `unattended-upgrades`, which automatically installs security patches daily. This is configured via cloud-init on server creation.

### Check status

```bash
# See what would be upgraded
sudo unattended-upgrades --dry-run

# Check logs
cat /var/log/unattended-upgrades/unattended-upgrades.log

# Check if a reboot is pending
ls /var/run/reboot-required
```

### What is automated

- Security updates from `Ubuntu-security` repository
- Runs daily via systemd timer

### What is NOT automated

- Non-security package updates
- Kernel reboots (a pending reboot flag is set, but the server won't reboot automatically)
- Docker updates
- Major OS upgrades

## Manual Package Updates

Run these periodically (monthly, or after security advisories).

### Single server

```bash
ssh kamal@<server-ip> "sudo apt update && sudo apt upgrade -y"
```

### All web servers (live has 2)

```bash
# Get server IPs
terraform workspace select live
terraform output web_server_ips

# Update each server
for ip in <web-1-ip> <web-2-ip>; do
  ssh kamal@$ip "sudo apt update && sudo apt upgrade -y"
done
```

### Accessory servers

```bash
ssh -J kamal@<web-ip> kamal@<accessory-ip> "sudo apt update && sudo apt upgrade -y"
```

## Docker Updates

Updating Docker restarts the daemon, which stops all running containers. Kamal will need to redeploy afterward.

### Stage (single server)

```bash
# Update Docker
ssh kamal@<web-ip> "sudo apt update && sudo apt install -y docker.io"

# Redeploy
kamal deploy -d stage
```

### Live (rolling update behind load balancer)

Update one web server at a time to avoid downtime:

```bash
# 1. Update web-1
ssh kamal@<web-1-ip> "sudo apt update && sudo apt install -y docker.io"

# 2. Redeploy (Kamal deploys to all hosts, containers restart)
kamal deploy -d live

# 3. Verify health — check the load balancer in Hetzner Console
#    or use: hcloud load-balancer describe fltyrd-live-web-load-balancer

# 4. Update web-2
ssh kamal@<web-2-ip> "sudo apt update && sudo apt install -y docker.io"

# 5. Redeploy again
kamal deploy -d live
```

### Accessory server

```bash
# Update Docker on accessories
ssh -J kamal@<web-ip> kamal@<accessory-ip> "sudo apt update && sudo apt install -y docker.io"

# Restart accessories (brief downtime for DB/Redis)
kamal accessory reboot -d live
```

## Rolling Reboots

Use this after kernel updates or when `/var/run/reboot-required` exists.

### Stage

```bash
# Reboot (brief downtime expected)
ssh kamal@<web-ip> "sudo reboot"

# Wait for server to come back, then verify
ssh kamal@<web-ip> "uptime"
```

### Live (zero-downtime)

Reboot one web server at a time behind the load balancer:

```bash
# 1. Check current LB health
hcloud load-balancer describe fltyrd-live-web-load-balancer

# 2. Reboot web-1
ssh kamal@<web-1-ip> "sudo reboot"

# 3. Wait for web-1 to come back and pass health checks
#    The LB checks /up on port 80 every 10 seconds
ssh kamal@<web-1-ip> "uptime"
hcloud load-balancer describe fltyrd-live-web-load-balancer

# 4. Reboot web-2
ssh kamal@<web-2-ip> "sudo reboot"

# 5. Wait and verify
ssh kamal@<web-2-ip> "uptime"
hcloud load-balancer describe fltyrd-live-web-load-balancer
```

### Accessory server reboot

This causes brief downtime for Postgres and Redis. Schedule during low-traffic periods.

```bash
# Ensure a fresh backup exists
# (automated backups run daily at 03:00 UTC via the backup-to-s3 container)

# Reboot
ssh -J kamal@<web-ip> kamal@<accessory-ip> "sudo reboot"

# Verify containers are running after reboot
ssh -J kamal@<web-ip> kamal@<accessory-ip> "docker ps"
```

## Immutable Server Replacement (OS Upgrades)

For major OS upgrades (e.g., Ubuntu 24.04 to 26.04) or significant base configuration changes, replace servers entirely rather than upgrading in-place.

### Prerequisites

- Verify the latest Postgres backup in the S3 backups bucket (`fltyrd-{workspace}-backups`)
- Trigger a manual backup if needed:
  ```bash
  ssh -J kamal@<web-ip> kamal@<accessory-ip> \
    "docker exec fltyrd-live-backup-to-s3 /backup.sh"
  ```

### Steps

1. **Update the OS image** in `variables.tf`:
   ```hcl
   variable "operating_system" {
     default = "ubuntu-26.04"  # update this
   }
   ```

2. **Taint the servers** to force recreation (the `ignore_changes = [user_data]` lifecycle rule prevents automatic recreation):
   ```bash
   terraform workspace select live

   # Taint web servers
   terraform taint 'hcloud_server.web_server[0]'
   terraform taint 'hcloud_server.web_server[1]'

   # Taint accessory server
   terraform taint 'hcloud_server.accessory_server[0]'
   ```

3. **Review the plan**:
   ```bash
   terraform plan
   ```
   Verify that only the tainted servers are being replaced. Networking, DNS, and storage should remain unchanged.

4. **Apply** (for live, use the CI pipeline or apply locally with caution):
   ```bash
   terraform apply
   ```
   New servers will be provisioned with the updated OS and cloud-init configuration. Cloud-init installs Docker, creates the `kamal` user, and configures SSH.

5. **Deploy the application** to the new servers:
   ```bash
   kamal setup -d live
   ```
   This sets up accessories (Postgres, Redis, backup-to-s3) and deploys the web application.

6. **Restore the database** from the S3 backup on the new accessory server.

7. **Verify** everything is working:
   ```bash
   # Check server status
   hcloud server list

   # Check app health
   curl -s https://fleetyards.net/up

   # Check load balancer
   hcloud load-balancer describe fltyrd-live-web-load-balancer

   # Check containers on accessories
   ssh -J kamal@<web-ip> kamal@<accessory-ip> "docker ps"
   ```

### Considerations

- Web servers are stateless — they can be replaced without data loss
- Accessory servers hold Postgres and Redis data in Docker volumes — **always back up before replacing**
- The load balancer selects targets by label (`http=yes,env=live`), so new servers are picked up automatically
- DNS records point to the server IPs (or LB IP for multi-server) — Terraform updates these if IPs change

## Pre-Maintenance Checklist

Before any maintenance:

- [ ] Check that automated Postgres backups are current
- [ ] Note current server IPs: `terraform output`
- [ ] For live: verify load balancer health: `hcloud load-balancer describe fltyrd-live-web-load-balancer`
- [ ] For live: schedule during low-traffic hours

## Post-Maintenance Verification

After any maintenance:

- [ ] App responds: `curl -s https://fleetyards.net/up` (or `fleetyards.dev` for stage)
- [ ] All containers running: `docker ps` on each server
- [ ] Load balancer healthy (live): `hcloud load-balancer describe fltyrd-live-web-load-balancer`
- [ ] No pending reboots: `ls /var/run/reboot-required`
