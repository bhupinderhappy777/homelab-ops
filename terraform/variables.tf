variable "prefix" {
  description = "Name prefix for created resources"
  type        = string
  default     = "homelab"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "canadacentral"
}

variable "resource_group" {
  description = "Resource group name"
  type        = string
  default     = "homelab-rg"
}

variable "vm_size" {
  description = "VM size"
  type        = string
  default     = "Standard_E2ads_v6"
}

variable "os_disk_size_gb" {
  description = "OS managed disk size in GB (Azure allows increase in place; grow the guest filesystem if the partition did not auto-expand)"
  type        = number
  default     = 200
}

variable "admin_username" {
  description = "Admin username for VM"
  type        = string
  default     = "deployuser"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key (used when ssh_public_key is empty)"
  type        = string
  default     = "~/.ssh/homelab_azure.pub"
}

variable "ssh_public_key" {
  description = "SSH public key material for the VM admin user. If empty, read from ssh_public_key_path."
  type        = string
  sensitive   = true
  default     = ""
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "dev"
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH to the VM"
  type        = string
  default     = "0.0.0.0/0"
}