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

@description('The test name in Azure Load Testing')
param loadTestTestName string = 'PostgreSQL Test Timed Load Testing'

@description('Number of threads for main database operations')
param mainThreads int = 10

@description('Number of loops for main database operations')
param mainLoops int = 100

@description('Number of threads for replica database operations')
param replicaThreads int = 40

@description('Number of loops for replica database operations')
param replicaLoops int = 400

@description('Main database writes per minute')
param mainWritesPerMinute int = 120

@description('Replica database reads per minute')
param replicaReadsPerMinute int = 480

@description('Number of engine instances for the load test')
param engineInstances int = 40

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
    postgresServerName: postgresServerName
    postgresAdminUsername: postgresAdminUsername
    postgresAdminPassword: postgresAdminPassword
    postgresDatabaseName: postgresDatabaseName
    location: location
    tags: tags
    keyVaultSku: keyVaultSku
    softDeleteRetentionInDays: softDeleteRetentionInDays
  }
}

// Deploy the load test configuration
module loadTestModule 'load_test.bicep' = {
  name: 'loadTestDeployment'
  scope: rg
  params: {
    loadTestName: loadTestName
    userAssignedIdentityId: resources.outputs.managedIdentityId
    keyVaultName: keyVaultName
    keyVaultUri: resources.outputs.keyVaultUri
    testName: loadTestTestName
    location: location
    primaryServerFqdn: resources.outputs.postgresServerFqdn
    replicaServerFqdn: resources.outputs.postgresReplicaServerFqdn
    mainThreads: mainThreads
    mainLoops: mainLoops
    replicaThreads: replicaThreads
    replicaLoops: replicaLoops
    mainWritesPerMinute: mainWritesPerMinute
    replicaReadsPerMinute: replicaReadsPerMinute
    engineInstances: engineInstances
    databaseName: postgresDatabaseName
  }
  // The dependsOn is automatically inferred from the property references
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
output postgresServerName string = resources.outputs.postgresServerName
output postgresServerFqdn string = resources.outputs.postgresServerFqdn
output postgresReplicaServerName string = resources.outputs.postgresReplicaServerName
output postgresReplicaServerFqdn string = resources.outputs.postgresReplicaServerFqdn
output loadTestConfigId string = loadTestModule.outputs.testId
output loadTestConfigName string = loadTestModule.outputs.testName