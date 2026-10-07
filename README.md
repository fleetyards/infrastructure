## Production-Grade (ish) server orchestration with Kamal

This is the architecture of our small cluster:

![Architecture](arch.png)

### Architecture

It creates two servers: `web` where our application lives and `accessories` where our dependencies like databases and caches live.
`web` exposes ports 80, 22 and 443, while `accessories` is not accessible from the outside. Root access is disabled on both machines and only the `kamal` user can SSH into them.

You can create more servers by updating `web_servers_count` or `accessories_count` in `variables.tf`. If there is more than one web server, a load balancer will be created and all the web servers will be added to it.

In case multiple servers of different types are created, the naming will be `web-1`, `web-2`, `accessories-1`, and `accessories-2`, as opposed to `web`, `accessories`, the default naming convention.

### Connecting to the servers

After running `terraform apply`, the script will output an SSH configuration that can be copied to your `~/.ssh/config` file. This is to help you connect to servers since accessory servers are not accessible from the outside, you need to use the web server as a jump host. It looks like this:

```ssh-config
ssh_01_web_config = <<EOT
Host web-1
  HostName 167.235.61.121
  User kamal
Host web-2
  HostName 5.75.160.210
  User kamal
EOT
ssh_02_accessories_config = <<EOT
Host accessories-1
  HostName 78.46.225.17
  User kamal
  ProxyJump web-1
Host accessories-2
  HostName 167.235.156.173
  User kamal
  ProxyJump web-1
Host accessories-3
  HostName 128.140.70.80
  User kamal
  ProxyJump web-1
EOT
```

### The machines

All machines are `CX22`: 2 AMD vCPUs, 2 GB of RAM and 40 GB of SSD storage, running Ubuntu 24.04. See `variables.tf` for more details and how to change them.

### Price

The default setup of 1 web server and 1 accessory server will cost you around 9 EUR/month.

### Setup

All credentials live in the `Fleetyards` 1Password vault. No `terraform.tfvars` file is needed — provider credentials are fetched at plan/apply time by the `onepassword` provider.

1. Install the tooling and sign in to 1Password:

```bash
brew install terraform 1password-cli
# then, in the 1Password desktop app:
# Settings -> Developer -> "Integrate with 1Password CLI"
```

2. Clone the repo and run the bootstrap script:

```bash
scripts/setup
```

It verifies the tooling, writes a gitignored `.env` with the S3 backend credentials and the 1Password service account token, and runs `terraform init`.

3. Load the credentials and pick a workspace:

```bash
source .env
terraform workspace select stage  # or live
terraform plan
terraform apply
```

The `.env` file is needed because the S3 backend initializes before any provider runs, so those two credentials cannot come from the `onepassword` provider itself.

#### SSH access to existing servers

Server logins are provisioned by cloud-init via `ssh_import_id: gh:<github_username>`, which only runs when a server is **created** — and `user_data` changes are ignored by lifecycle rules. A new SSH key added to GitHub will therefore not reach servers that already exist. Either reuse your existing key or append the new public key to `~/.ssh/authorized_keys` for the `kamal` user on each server.
