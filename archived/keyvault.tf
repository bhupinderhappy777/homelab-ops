# ARCHIVED — not loaded by Terraform. Optional lab Key Vault in the compute RG was removed
# so secrets stay in vault-rg (or your chosen vault). SSH admin key locals live in terraform/main.tf.
#
data "azurerm_client_config" "current" {}

resource "random_id" "keyvault_suffix" {
  byte_length = 4
}

resource "azurerm_key_vault" "homelab" {
  name                       = "${var.prefix}${random_id.keyvault_suffix.hex}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
    ]
  }

  tags = {
    environment = var.environment
  }
}
