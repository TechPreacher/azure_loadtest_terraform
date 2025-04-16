// Resources to be deployed in the resource group

@description('The name of the Azure Load Test resource')
param loadTestName string

@description('The name of the User Assigned Managed Identity')
param identityName string

@description('The name of the Key Vault')
param keyVaultName string

@description('The name of the PostgreSQL Flexible Server')
param postgresServerName string

@description('The admin username for PostgreSQL')
@secure()
param postgresAdminUsername string

@description('The admin password for PostgreSQL')
@secure()
param postgresAdminPassword string

@description('The name of the PostgreSQL database')
param postgresDatabaseName string = 'test'

@description('Location for all resources')
param location string

@description('Tags for all resources')
param tags object = {}

@description('SKU name for the Key Vault')
param keyVaultSku string = 'standard'

@description('Soft delete retention period in days')
param softDeleteRetentionInDays int = 7

resource loadTest 'Microsoft.LoadTestService/loadTests@2022-12-01' = {
  name: loadTestName
  location: location
  tags: tags
  properties: {}
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: tags
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    tenantId: subscription().tenantId
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionInDays
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: managedIdentity.properties.principalId
        permissions: {
          keys: ['all']
          secrets: ['all']
          certificates: ['all']
        }
      }
    ]
    sku: {
      name: keyVaultSku
      family: 'A'
    }
  }
}

// Assign Key Vault Administrator role to the managed identity
resource keyVaultAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, managedIdentity.id, '00482a5a-887f-4fb3-b363-3b7fe8e74483')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483') // Key Vault Administrator
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// PostgreSQL Flexible Server - Primary
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: postgresServerName
  location: location
  tags: tags
  sku: {
    name: 'Standard_E2ds_v5'
    tier: 'MemoryOptimized'
  }
  properties: {
    version: '14'
    administratorLogin: postgresAdminUsername
    administratorLoginPassword: postgresAdminPassword
    storage: {
      storageSizeGB: 128
      autoGrow: 'Disabled'
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
      tenantId: subscription().tenantId
    }
    highAvailability: {
      mode: 'Disabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
  }
}

// PostgreSQL Firewall Rules - Allow all
resource postgresFirewallRuleAllowAll 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2022-12-01' = {
  name: 'AllowAll'
  parent: postgresServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

// Allow Azure services
resource postgresAllowAzureServices 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2022-12-01' = {
  name: 'AllowAzureServices'
  parent: postgresServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Database
resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2022-12-01' = {
  name: postgresDatabaseName
  parent: postgresServer
  properties: {
    charset: 'UTF8'
    collation: 'en_US.UTF8'
  }
}

// Store PostgreSQL credentials in Key Vault
resource postgresUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'postgres-username'
  properties: {
    value: postgresAdminUsername
  }
}

resource postgresPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'postgres-password'
  properties: {
    value: postgresAdminPassword
  }
}

// Store server and database information in Key Vault
resource postgresServerSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'postgres-server'
  properties: {
    value: postgresServer.name
  }
}

resource postgresDatabaseSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'postgres-database'
  properties: {
    value: postgresDatabaseName
  }
}

resource postgresFqdnSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'postgres-fqdn'
  properties: {
    value: postgresServer.properties.fullyQualifiedDomainName
  }
}

// PostgreSQL Replica Server
resource postgresReplicaServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: '${postgresServerName}repl'
  location: location
  tags: tags
  sku: {
    name: 'Standard_E2ds_v5'
    tier: 'MemoryOptimized'
  }
  properties: {
    // Properly set up this server as a replica using createMode
    createMode: 'Replica'
    sourceServerResourceId: postgresServer.id
    
    // These settings are inherited from the source server but can be adjusted if needed
    version: '14'
    administratorLogin: postgresAdminUsername
    administratorLoginPassword: postgresAdminPassword
    storage: {
      storageSizeGB: 128
      autoGrow: 'Disabled'
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Enabled'
      tenantId: subscription().tenantId
    }
    highAvailability: {
      mode: 'Disabled'
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
  }
  dependsOn: [
    postgresDatabase  // Make sure the database exists before creating the replica
  ]
}

// Store replica server information in Key Vault
resource postgresReplicaServerSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'postgres-replica-server'
  properties: {
    value: postgresReplicaServer.name
  }
}

resource postgresReplicaFqdnSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: 'postgres-replica-fqdn'
  properties: {
    value: postgresReplicaServer.properties.fullyQualifiedDomainName
  }
}

// Add instructions for manually configuring AD admin
resource deploymentMessage 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'deploymentMessage'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.44.0'
    retentionInterval: 'P1D'
    timeout: 'PT5M'
    scriptContent: '''
      echo "=== IMPORTANT: Manual action required ==="
      echo "After deployment, you need to manually add an AD admin to the primary PostgreSQL server."
      echo "The replica server will inherit the AD admin configuration automatically."
      echo ""
      echo "Run the following command to add an AD admin:"
      echo ""
      echo "az postgres flexible-server ad-admin create \\"
      echo "  --server-name $POSTGRES_SERVER \\"
      echo "  --resource-group $RESOURCE_GROUP \\"
      echo "  --object-id <your-aad-object-id> \\"
      echo "  --principal-type User \\"
      echo "  --display-name <your-aad-display-name>"
      echo ""
      echo "=== End of Manual Actions ==="
    '''
    environmentVariables: [
      {
        name: 'POSTGRES_SERVER'
        value: postgresServerName
      }
      {
        name: 'RESOURCE_GROUP'
        value: resourceGroup().name
      }
    ]
  }
  dependsOn: [
    postgresServer
    postgresReplicaServer
  ]
}

output loadTestId string = loadTest.id
output loadTestName string = loadTest.name
output managedIdentityId string = managedIdentity.id
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output managedIdentityClientId string = managedIdentity.properties.clientId
output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
output postgresServerName string = postgresServer.name
output postgresServerFqdn string = postgresServer.properties.fullyQualifiedDomainName
output postgresReplicaServerName string = postgresReplicaServer.name
output postgresReplicaServerFqdn string = postgresReplicaServer.properties.fullyQualifiedDomainName
output manualActionRequired string = 'After deployment, manually add AAD admin to PostgreSQL servers. See deployment script output for instructions.'