// Azure Load Test for Azure Database for PostgreSQL Bicep template
// This template deploys an Azure Load Test resource, an Azure KeyVault, an Azure Database for PostgreSQL Flexible Server with a replica and a User Assigned Managed Identity to access KeyVault from the load test.
// The load test uses an Apache JMeter script to test the database.
// User credentials and JMeter script parameters are stored in the KeyVault.

targetScope = 'subscription'

@description('The name of the resource group')
param resourceGroupName string

@description('The name of the Azure Load Test resource')
param loadTestName string

@description('The name of the User Assigned Managed Identity')
param identityName string

@description('The name of the Key Vault')
param keyVaultName string

@description('Location for all resources')
param location string

@description('Tags for all resources')
param tags object = {}

@description('SKU name for the Key Vault')
param keyVaultSku string = 'standard'

@description('Soft delete retention period in days')
param softDeleteRetentionInDays int = 7

// Create the resource group
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// Deploy resources to the resource group
module resources 'resources.bicep' = {
  name: 'resourcesDeployment'
  scope: rg
  params: {
    loadTestName: loadTestName
    identityName: identityName
    keyVaultName: keyVaultName
    location: location
    tags: tags
    keyVaultSku: keyVaultSku
    softDeleteRetentionInDays: softDeleteRetentionInDays
  }
}

output resourceGroupName string = rg.name
output resourceGroupId string = rg.id
output loadTestId string = resources.outputs.loadTestId
output loadTestName string = resources.outputs.loadTestName
output managedIdentityId string = resources.outputs.managedIdentityId
output managedIdentityPrincipalId string = resources.outputs.managedIdentityPrincipalId
output managedIdentityClientId string = resources.outputs.managedIdentityClientId
output keyVaultId string = resources.outputs.keyVaultId
output keyVaultName string = resources.outputs.keyVaultName
output keyVaultUri string = resources.outputs.keyVaultUri