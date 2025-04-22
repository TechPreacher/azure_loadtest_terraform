# Azure Load Test Terraform Configuration

This folder contains Terraform configuration to deploy Azure Load Test and PostgreSQL infrastructure.

## Resources Deployed

- Resource Group
- Azure Load Test resource
- Azure Load Test configuration
- User Assigned Managed Identity
- Key Vault with the Managed Identity assigned as Key Vault Administrator
- PostgreSQL Flexible Server (Memory Optimized, Standard_E2ds_v5)
  - Primary server
  - Test database
  - Public network access enabled
  - Microsoft Entra authentication enabled
- PostgreSQL Flexible Server Replica
  - Read-only replica of the primary server
  - Created using 'Replica' create mode

## Prerequisites

1. [Terraform](https://www.terraform.io/downloads.html) (v1.0.0 or newer)
2. [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (logged in and subscription set)

## Deployment Steps

### Using the Makefile

The project includes a Makefile in the parent directory with Terraform commands:

```bash
# Initialize Terraform
make init

# Validate Terraform configuration
make validate

# Preview changes
make plan SUBSCRIPTION_ID=your-subscription-id

# Apply configuration
make apply SUBSCRIPTION_ID=your-subscription-id

# Destroy infrastructure when done
make destroy SUBSCRIPTION_ID=your-subscription-id
```

### Manual Deployment

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Review the deployment plan:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

4. If you want to customize the deployment, either:
   - Edit `terraform.tfvars` file
   - Or pass variables on the command line:
     ```bash
     terraform apply -var="resource_group_name=my-custom-rg" -var="location=westeurope"
     ```

## Post-Deployment Steps

After deployment:

1. The User Assigned Managed Identity is automatically configured as a Microsoft Entra administrator for the PostgreSQL server.

2. Upload load test files through the Azure Portal:
   - Navigate to Azure Portal > Load Testing > [Load Test Name] > Tests
   - Click on the test configuration
   - Click 'Edit' and upload:
     - JMeter script: `load_test_artifacts/jmeter_script.jmx`
     - PostgreSQL JDBC driver: `load_test_artifacts/postgresql-42.7.5.jar` (in the 'Additional Files' section)

## Clean Up

To remove all deployed resources:

```bash
terraform destroy
```

## Notes

- The PostgreSQL password is stored in the Terraform state file in plaintext. For production, consider using a more secure approach for secrets management.
- The Load Test files need to be uploaded manually as Terraform doesn't support direct file uploads.

## Reliability Features

This Terraform configuration implements several reliability features to handle Azure API limitations:

1. **Extended Timeouts**: All resources have configured timeouts to allow more time for operations to complete.

2. **Time Delays**: Strategic delays between operations using `time_sleep` resources:
   - 30-second delay after PostgreSQL server creation before creating firewall rules
   - 60-second delay before creating the replica server
   - 30-second delay before creating Key Vault secrets

3. **Explicit Dependencies**: Resources declare explicit dependencies to ensure proper provisioning order.

4. **Azure Provider Configuration**:
   - Higher timeouts for client operations (30 minutes)
   - Improved recovery options for Key Vault and other resources
   - Force wait for PostgreSQL operations to complete

5. **PostgreSQL-specific Improvements**:
   - Firewall rules creation separated to avoid concurrent operation issues
   - Replica server created only after database is confirmed ready
   - Careful ordering of resource creation to avoid "server busy" errors

These features help avoid common deployment issues with Azure PostgreSQL Flexible Server, such as:
- "Server busy with another operation" errors
- Key Vault access policy conflicts
- Timing issues with replica creation
- Secret creation failures