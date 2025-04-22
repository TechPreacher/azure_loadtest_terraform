output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "resource_group_id" {
  value = azurerm_resource_group.main.id
}

output "load_test_id" {
  value = azurerm_load_test.main.id
}

output "load_test_name" {
  value = azurerm_load_test.main.name
}

output "managed_identity_id" {
  value = azurerm_user_assigned_identity.main.id
}

output "managed_identity_principal_id" {
  value = azurerm_user_assigned_identity.main.principal_id
}

output "managed_identity_client_id" {
  value = azurerm_user_assigned_identity.main.client_id
}

output "key_vault_id" {
  value = azurerm_key_vault.main.id
}

output "key_vault_name" {
  value = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

output "postgres_server_name" {
  value = azurerm_postgresql_flexible_server.primary.name
}

output "postgres_server_fqdn" {
  value = azurerm_postgresql_flexible_server.primary.fqdn
}

output "postgres_replica_server_name" {
  value = azurerm_postgresql_flexible_server.replica.name
}

output "postgres_replica_server_fqdn" {
  value = azurerm_postgresql_flexible_server.replica.fqdn
}

output "load_test_config_name" {
  value = var.load_test_test_name
  description = "The name for the load test configuration (to be created manually)"
}

output "manual_action_required" {
  value = "After deployment, upload test files. The User Assigned Managed Identity is automatically configured as a Microsoft Entra administrator. See manual steps reminder output for instructions."
}