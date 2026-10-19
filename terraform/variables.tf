############################################
# Core
############################################

variable "aws_region" {
  description = "AWS region to deploy the lab into."
  type        = string
  default     = "us-east-1"
}

variable "owner_tag" {
  description = "Free-form owner tag applied to all resources (e.g. your name or email)."
  type        = string
  default     = "koi-pov"
}

variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
  default     = "koi-lab"
}

############################################
# OS edition
#   server2022  -> AWS-provided, shared-tenancy AMI. Works on `apply` with no extra steps.
#                  Koi/AES discovery behaviour is IDENTICAL to a Windows client for our
#                  purposes (same user-profile paths, same extension/MCP/AI-tool enumeration).
#   windows11   -> Windows CLIENT OS. Microsoft licensing requires a DEDICATED HOST and
#                  BYOL media. You must supply your own Win11 AMI id (var.windows11_ami_id).
#                  Costs more and takes more setup. Use only when you need a pixel-accurate
#                  desktop for a demo. See docs/WINDOWS11_NOTES.md.
############################################

variable "os_edition" {
  description = "Which Windows edition to launch: 'server2022' (default, works out of the box) or 'windows11' (dedicated host + BYOL)."
  type        = string
  default     = "server2022"

  validation {
    condition     = contains(["server2022", "windows11"], var.os_edition)
    error_message = "os_edition must be either 'server2022' or 'windows11'."
  }
}

variable "windows11_ami_id" {
  description = "Required only when os_edition = 'windows11'. The id of a Windows 11 BYOL AMI you have imported into this account/region."
  type        = string
  default     = ""
}

############################################
# Instance sizing
############################################

variable "instance_type" {
  description = "EC2 instance type. t3.large (2 vCPU / 8 GB) is the comfortable minimum for a GUI + the agentic toolset; bump to t3.xlarge if it feels sluggish."
  type        = string
  default     = "t3.large"
}

variable "root_volume_gb" {
  description = "Root EBS volume size in GiB. The agentic payload (IDEs, AI tools, WinPython) wants headroom."
  type        = number
  default     = 100
}

############################################
# Access
############################################

variable "allowed_rdp_cidr" {
  description = "Source allowed to reach RDP (3389). Set to YOUR PUBLIC IP (from https://checkip.amazonaws.com). A bare IP (\"203.0.113.7\") or a CIDR (\"203.0.113.7/32\") both work - a bare IP gets /32 appended automatically. Do NOT use a private 10./172.16./192.168. address: it will not reach a public EC2 instance from the internet. Leave empty to auto-detect your current egress IP."
  type        = string
  default     = ""
}

variable "key_pair_name" {
  description = "Name to give the generated EC2 key pair (used to decrypt the Windows admin password)."
  type        = string
  default     = "koi-lab-key"
}

variable "private_key_output_path" {
  description = "Local path where the generated private key (.pem) is written. Keep this out of git."
  type        = string
  default     = "./koi-lab-key.pem"
}

############################################
# Provisioning behaviour
############################################

variable "auto_provision" {
  description = "If true, user_data runs base machine prep at boot (Chocolatey, git, TLS). The per-USER light-up payload is still intended to be run interactively over RDP as the logged-in user, because Koi discovers per-user profiles and user_data runs as SYSTEM."
  type        = bool
  default     = true
}
