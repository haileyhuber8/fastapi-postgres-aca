# ------------------------------------------------------------------------------------------------------
# DEPLOY AZURE KEYVAULT
# ------------------------------------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

locals {
  # Build list of access policies dynamically
  access_policies = concat(
    [
      # Access policy for the current Terraform client (local runs)
      {
        tenant_id = data.azurerm_client_config.current.tenant_id
        object_id = data.azurerm_client_config.current.object_id
        secret_permissions = [
          "Get", "List", "Set", "Delete", "Purge", "Recover"
        ]
      }
    ],
    # Conditionally add GitHub Actions access policy if object_id is provided
    var.github_actions_principal_id != null ? [
      {
        tenant_id = data.azurerm_client_config.current.tenant_id
        object_id = var.github_actions_principal_id
        secret_permissions = [
          "Get", "List", "Set", "Delete", "Purge", "Recover"
        ]
      }
    ] : []
  )
}

resource "azurerm_key_vault" "kv" {
  name                     = "${var.prefix}-kv"
  location                 = var.location
  resource_group_name      = var.rg_name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled = false
  sku_name                 = "standard"

  tags = var.tags

  # Apply all access policies (local client + GitHub Actions if provided)
  dynamic "access_policy" {
    for_each = local.access_policies
    content {
      tenant_id          = access_policy.value.tenant_id
      object_id          = access_policy.value.object_id
      secret_permissions = access_policy.value.secret_permissions
    }
  }
}

resource "azurerm_key_vault_secret" "secrets" {
  count        = length(var.secrets)
  name         = var.secrets[count.index].name
  value        = var.secrets[count.index].value
  key_vault_id = azurerm_key_vault.kv.id
}
