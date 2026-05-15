output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.pip.ip_address
}

output "vm_id" {
  description = "ID of the VM"
  value       = azurerm_linux_virtual_machine.vm.id
}
output "vm_private_ip" {
  description = "Private IP address of the VM"
  value       = azurerm_network_interface.nic.private_ip_address
}

output "admin_username" {
  description = "Admin username for the VM"
  value       = var.admin_username
}

output "key_vault_name" {
  description = "Azure Key Vault name (use with az keyvault secret …)"
  value       = azurerm_key_vault.homelab.name
}

output "key_vault_uri" {
  description = "Azure Key Vault URI (set AZURE_KEY_VAULT_URI for Ansible)"
  value       = azurerm_key_vault.homelab.vault_uri
}
