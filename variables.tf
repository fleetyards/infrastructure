variable "hetzner_api_key" {
  description = "The Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "The name of the SSH key on cloud.hetzner.de to be used for server access."
  type        = string
  sensitive   = true
}

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
  }))
  default = {
    default = {
      server_type       = "cx23"
      web_servers_count = 1
      accessories_count = 1
    }
    stage = {
      server_type       = "cx23"
      web_servers_count = 1
      accessories_count = 1
    }
    live = {
      server_type       = "cx32"
      web_servers_count = 2
      accessories_count = 1
    }
  }
}

variable "username" {
  description = "The username for SSH access to the servers."
  type        = string
  default     = "kamal"
}

variable "github_username" {
  description = "The GitHub username of the user to be used for SSH access. This is used to fetch SSH keys from GitHub."
  type        = string
}
