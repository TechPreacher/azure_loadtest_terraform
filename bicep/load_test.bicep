// Azure Load Test configuration module

@description('The name of the existing Azure Load Test resource')
param loadTestName string

@description('The name of the User Assigned Managed Identity to use for Key Vault access')
param userAssignedIdentityId string

@description('The Key Vault name containing the secrets')
param keyVaultName string

@description('The Key Vault URI')
param keyVaultUri string

@description('The test name in Azure Load Testing')
param testName string = 'PostgreSQL Test Timed Load Testing'

@description('Location for all resources')
param location string

@description('Primary PostgreSQL server FQDN')
param primaryServerFqdn string

@description('Replica PostgreSQL server FQDN')
param replicaServerFqdn string

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

@description('Database name in PostgreSQL server')
param databaseName string = 'test'

// Files need to be uploaded manually after deployment
// See fileUploadReminder deployment script for details

// Reference the existing Azure Load Test resource
resource loadTestResource 'Microsoft.LoadTestService/loadTests@2022-12-01' existing = {
  name: loadTestName
}

// Create the load test
resource loadTest 'Microsoft.LoadTestService/loadTests/tests@2022-12-01' = {
  parent: loadTestResource
  name: testName
  properties: {
    description: 'Load test for PostgreSQL primary and replica databases'
    displayName: testName
    loadTestConfiguration: {
      engineInstances: engineInstances
      splitAllCSVs: false
      quickStartTest: false
    }
    environmentVariables: {
      main_threads: '${mainThreads}'
      main_loops: '${mainLoops}'
      main_database: 'jdbc:postgresql://${primaryServerFqdn}:5432/${databaseName}'
      replica_threads: '${replicaThreads}'
      replica_loops: '${replicaLoops}'
      replica_database: 'jdbc:postgresql://${replicaServerFqdn}:5432/${databaseName}'
      main_writes_per_minute: '${mainWritesPerMinute}'
      replica_reads_per_minute: '${replicaReadsPerMinute}'
    }
    secrets: {
      mainuser: {
        type: 'AKV_SECRET_URI'
        value: '${keyVaultUri}secrets/postgres-username'
      }
      mainpassword: {
        type: 'AKV_SECRET_URI'
        value: '${keyVaultUri}secrets/postgres-password'
      }
      replicauser: {
        type: 'AKV_SECRET_URI'
        value: '${keyVaultUri}secrets/postgres-username'  // Using the same credentials for replica
      }
      replicapassword: {
        type: 'AKV_SECRET_URI'
        value: '${keyVaultUri}secrets/postgres-password'  // Using the same credentials for replica
      }
    }
    secretsConfiguration: {
      keyVaultId: resourceId('Microsoft.KeyVault/vaults', keyVaultName)
      identityId: userAssignedIdentityId
    }
    testType: 'JMX'
    passFailCriteria: {
      passFailMetrics: {
        totalRequests: {
          aggregate: 'avg'
          clientMetric: 'request_count'
          condition: '>='
          value: 1
        }
        averageResponseTime: {
          aggregate: 'avg'
          clientMetric: 'response_time_ms'
          condition: '<='
          value: 5000
        }
        requestsPerSec: {
          aggregate: 'avg'
          clientMetric: 'requests_per_sec'
          condition: '>='
          value: 1
        }
      }
    }
    // Need to manually upload the files after deployment
    // The test plan file and JDBC driver will need to be uploaded using the Azure Portal or REST API
  }
}

// Create manual file upload reminder
resource fileUploadReminder 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'fileUploadReminder'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.44.0'
    retentionInterval: 'P1D'
    timeout: 'PT5M'
    scriptContent: '''
      echo "=== IMPORTANT: Manual action required for Load Test ==="
      echo "After deployment, you need to manually upload the test files:"
      echo ""
      echo "1. Navigate to the Azure Portal → Azure Load Testing → $LOAD_TEST_NAME → Tests → $TEST_NAME"
      echo "2. Click 'Edit' on the test"
      echo "3. Upload the following files:"
      echo "   - JMeter script: load_test_artifacts/jmeter_script.jmx"
      echo "   - PostgreSQL JDBC driver: load_test_artifacts/postgresql-42.7.5.jar (in the 'Additional Files' section)"
      echo ""
      echo "Alternatively, you can use REST API to upload the files:"
      echo "az rest --method PUT --uri ${environment().resourceManager}/subscriptions/{subscriptionId}/resourceGroups/{resourceGroup}/providers/Microsoft.LoadTestService/loadTests/$LOAD_TEST_NAME/tests/$TEST_NAME/files/{fileName}?api-version=2022-12-01 --body @{filePath}"
      echo ""
      echo "=== End of Manual Actions ==="
    '''
    environmentVariables: [
      {
        name: 'LOAD_TEST_NAME'
        value: loadTestName
      }
      {
        name: 'TEST_NAME'
        value: testName
      }
    ]
  }
}

// Output the load test details
output loadTestId string = loadTest.id
output loadTestName string = loadTestResource.name
output testId string = loadTest.id
output testName string = loadTest.name