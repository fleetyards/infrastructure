variable "region" {
  description = "The Hetzner Cloud region where resources will be provisioned. See https://docs.hetzner.com/cloud/general/locations for available locations."
  type        = string
  default     = "nbg1"

  validation {
    condition     = contains(["fsn1", "nbg1", "hel1", "ash", "hil", "sin"], var.region)
    error_message = "The region must be one of fsn1, nbg1, hel1, ash, hil, or sin."
  }
}

variable "operating_system" {
  description = "The operating system image to use for the servers."
  type        = string
  default     = "ubuntu-24.04"
}

variable "env_config" {
  description = "Per-environment server configuration, keyed by workspace name."
  type = map(object({
    server_type       = string
    web_servers_count = number
    accessories_count = number
    domains           = list(string)
    short_domains     = list(string)
    cors_origins      = list(string)
  }))
  default = {
    default = {
      server_type       = "cx23"
      web_servers_count = 1
      accessories_count = 1
      domains           = []
      short_domains     = []
      cors_origins      = ["http://fleetyards.test", "http://*.fleetyards.test"]
    }
    stage = {
      server_type       = "cx23"
      web_servers_count = 1
      accessories_count = 1
      domains           = ["fleetyards.dev"]
      short_domains     = ["fltyrd.dev"]
      cors_origins      = ["https://fleetyards.dev", "https://*.fleetyards.dev"]
    }
    live = {
      server_type       = "cx33"
      web_servers_count = 2
      accessories_count = 1
      domains           = ["fleetyards.net"]
      short_domains     = ["fltyrd.net"]
      cors_origins      = ["https://fleetyards.net", "https://*.fleetyards.net"]
    }
  }
}

variable "manage_dns" {
  description = "Whether to create DNS records. Set to false when provisioning infrastructure ahead of a migration to avoid pointing DNS at servers that aren't ready yet."
  type        = bool
  default     = true
}

variable "enable_ssl" {
  description = "Whether to enable SSL on the load balancer. Requires DNS to be pointing at the LB first (managed certs use HTTP-01 validation)."
  type        = bool
  default     = false
}

variable "maintenance" {
  description = "Enable maintenance mode. Relaxes LB health checks to accept 503 responses so kamal-proxy can serve a maintenance page."
  type        = bool
  default     = false
}

variable "username" {
  description = "The username for SSH access to the servers."
  type        = string
  default     = "kamal"
}

variable "github_username" {
  description = "The GitHub username of the user to be used for SSH access. This is used to fetch SSH keys from GitHub."
  type        = string
  default     = "mortik"
}


