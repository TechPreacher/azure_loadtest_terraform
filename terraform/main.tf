# Required provider versions
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">=0.9.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">=2.0.0"
    }
  }
  required_version = ">= 1.0.0"
}

# Azure provider configuration
provider "azurerm" {
  # These environment variables would be set automatically when using the Makefile
  # ARM_SUBSCRIPTION_ID
  # ARM_CLIENT_ID
  # ARM_CLIENT_SECRET
  # ARM_TENANT_ID
  # For manual testing, we can use a placeholder or get from variables
  subscription_id = var.subscription_id
  
  # Disable automatic resource provider registration
  # This is needed if the user doesn't have permissions to register resource providers
  resource_provider_registrations = "none"
  
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    
    # Add retry logic for resource operations
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    
    # Add API management feature
    api_management {
      recover_soft_deleted = true
    }
    
    # Improve virtual machine behavior
    virtual_machine {
      delete_os_disk_on_deletion     = true
      skip_shutdown_and_force_delete = true
    }
  }
}

# Resource group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# User Assigned Managed Identity
resource "azurerm_user_assigned_identity" "main" {
  name                = var.identity_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags
}

# Azure Key Vault
resource "azurerm_key_vault" "main" {
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = var.soft_delete_retention_days
  purge_protection_enabled    = false
  sku_name                    = var.key_vault_sku
  
  # Network configuration - Allow public access from all networks
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  # Add access policy for the currently logged-in user or service principal
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Get", "List", "Create", "Delete", "Update", "Recover", "Purge", "GetRotationPolicy"
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
    ]

    certificate_permissions = [
      "Get", "List", "Create", "Delete", "Update", "Recover", "Purge"
    ]
  }

  # Add access policy for the managed identity
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = azurerm_user_assigned_identity.main.principal_id

    key_permissions = [
      "Get", "List", "Create", "Delete", "Update", "Recover", "Purge", "GetRotationPolicy"
    ]

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Recover", "Backup", "Restore", "Purge"
    ]

    certificate_permissions = [
      "Get", "List", "Create", "Delete", "Update", "Recover", "Purge"
    ]
  }

  tags = var.tags
}

# Azure RBAC role assignment for Key Vault
resource "azurerm_role_assignment" "key_vault_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

# PostgreSQL Flexible Server - Primary
resource "azurerm_postgresql_flexible_server" "primary" {
  name                   = var.postgres_server_name
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "14"
  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password
  storage_mb             = 131072 # 128 GB
  sku_name               = "MO_Standard_E2ds_v5"
  zone                   = "1"    # Explicitly set zone to match HA config
  
  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = true
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  tags = var.tags
  
  timeouts {
    create = "60m"
    update = "60m"
    delete = "30m"
  }
}

# Configure Active Directory Administrator for PostgreSQL
resource "azurerm_postgresql_flexible_server_active_directory_administrator" "primary" {
  server_name         = azurerm_postgresql_flexible_server.primary.name
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  object_id           = azurerm_user_assigned_identity.main.principal_id
  principal_name      = azurerm_user_assigned_identity.main.name
  principal_type      = "ServicePrincipal"  # ServicePrincipal for managed identities
}

# PostgreSQL Firewall Rules - Allow all
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_all" {
  name             = "AllowAll"
  server_id        = azurerm_postgresql_flexible_server.primary.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
  
  # Add explicit dependency to ensure server is fully provisioned
  depends_on = [
    azurerm_postgresql_flexible_server.primary,
    # Include a time delay to ensure the server is ready for firewall rule creation
    time_sleep.wait_30_seconds
  ]

  # Use timeouts to give operations more time to complete
  timeouts {
    create = "10m"
    delete = "10m"
  }
}

# Add a sleep resource to wait between resource creation operations
resource "time_sleep" "wait_30_seconds" {
  depends_on = [azurerm_postgresql_flexible_server.primary]
  create_duration = "30s"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.primary.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
  
  # Add explicit dependency to wait for the first firewall rule
  depends_on = [
    azurerm_postgresql_flexible_server_firewall_rule.allow_all,
    time_sleep.wait_30_seconds
  ]
  
  # Use timeouts to give operations more time to complete
  timeouts {
    create = "10m"
    delete = "10m"
  }
}

# Database
resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = var.postgres_database_name
  server_id = azurerm_postgresql_flexible_server.primary.id
  charset   = "UTF8"
  collation = "en_US.utf8"  # lowercase utf8 is required by Terraform
  
  # Add dependency on firewall rules
  depends_on = [
    azurerm_postgresql_flexible_server_firewall_rule.allow_all,
    azurerm_postgresql_flexible_server_firewall_rule.allow_azure_services
  ]
  
  # Use timeouts to give operations more time to complete
  timeouts {
    create = "30m"
    delete = "30m"
  }
}

# Add a delay before creating the replica
resource "time_sleep" "wait_before_replica" {
  depends_on = [
    azurerm_postgresql_flexible_server_database.main,
    azurerm_postgresql_flexible_server_firewall_rule.allow_all,
    azurerm_postgresql_flexible_server_firewall_rule.allow_azure_services
  ]
  create_duration = "60s"
}

# PostgreSQL Replica Server
resource "azurerm_postgresql_flexible_server" "replica" {
  name                   = "${var.postgres_server_name}repl"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "14"
  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password
  storage_mb             = 131072 # 128 GB
  sku_name               = "MO_Standard_E2ds_v5"
  create_mode            = "Replica"
  source_server_id       = azurerm_postgresql_flexible_server.primary.id
  zone                   = "3"    # Choose a different zone from primary

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = true
    tenant_id                     = data.azurerm_client_config.current.tenant_id
  }

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  depends_on = [
    azurerm_postgresql_flexible_server_database.main,
    time_sleep.wait_before_replica
  ]

  # Use timeouts to give operations more time to complete
  timeouts {
    create = "60m"  # Creating a replica can take a long time
    update = "60m"
    delete = "30m"
  }

  tags = var.tags
}

# Add a delay before creating Key Vault secrets
resource "time_sleep" "wait_before_secrets" {
  depends_on = [
    azurerm_key_vault.main,
    azurerm_role_assignment.key_vault_admin
  ]
  create_duration = "30s"
}

# Key Vault Secrets
resource "azurerm_key_vault_secret" "postgres_username" {
  name         = "postgres-username"
  value        = var.postgres_admin_username
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [
    azurerm_key_vault.main,
    time_sleep.wait_before_secrets
  ]
  
  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
    read   = "5m"
  }
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-password"
  value        = var.postgres_admin_password
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [
    azurerm_key_vault.main,
    time_sleep.wait_before_secrets
  ]
  
  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
    read   = "5m"
  }
}

resource "azurerm_key_vault_secret" "postgres_server" {
  name         = "postgres-server"
  value        = azurerm_postgresql_flexible_server.primary.name
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [
    azurerm_key_vault.main,
    azurerm_postgresql_flexible_server.primary,
    time_sleep.wait_before_secrets
  ]
  
  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
    read   = "5m"
  }
}

resource "azurerm_key_vault_secret" "postgres_database" {
  name         = "postgres-database"
  value        = var.postgres_database_name
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [
    azurerm_key_vault.main,
    time_sleep.wait_before_secrets
  ]
  
  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
    read   = "5m"
  }
}

resource "azurerm_key_vault_secret" "postgres_fqdn" {
  name         = "postgres-fqdn"
  value        = azurerm_postgresql_flexible_server.primary.fqdn
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [
    azurerm_key_vault.main,
    azurerm_postgresql_flexible_server.primary,
    time_sleep.wait_before_secrets
  ]
  
  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
    read   = "5m"
  }
}

# Add a delay before creating replica-related secrets
resource "time_sleep" "wait_before_replica_secrets" {
  depends_on = [
    azurerm_postgresql_flexible_server.replica,
    azurerm_key_vault_secret.postgres_fqdn
  ]
  create_duration = "30s"
}

resource "azurerm_key_vault_secret" "postgres_replica_server" {
  name         = "postgres-replica-server"
  value        = azurerm_postgresql_flexible_server.replica.name
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [
    azurerm_key_vault.main,
    azurerm_postgresql_flexible_server.replica,
    time_sleep.wait_before_replica_secrets
  ]
  
  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
    read   = "5m"
  }
}

resource "azurerm_key_vault_secret" "postgres_replica_fqdn" {
  name         = "postgres-replica-fqdn"
  value        = azurerm_postgresql_flexible_server.replica.fqdn
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [
    azurerm_key_vault.main,
    azurerm_postgresql_flexible_server.replica,
    time_sleep.wait_before_replica_secrets
  ]
  
  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
    read   = "5m"
  }
}

# Azure Load Test
resource "azurerm_load_test" "main" {
  name                = var.load_test_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = var.tags
  
  # Assign the managed identity to the load test
  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }
  
  # Add depends_on to ensure it's created after the database resources
  depends_on = [
    azurerm_postgresql_flexible_server.primary,
    azurerm_postgresql_flexible_server.replica,
    azurerm_key_vault_secret.postgres_replica_fqdn
  ]
  
  # Use timeouts to give operations more time to complete
  timeouts {
    create = "20m"
    delete = "20m"
  }
}