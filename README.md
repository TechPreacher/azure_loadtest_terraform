# Azure Load Test Bicep Project for Azure Database for PostgreSQL Flexible Server with Replica

This project contains Bicep templates for deploying Azure Load Test resources.
This template deploys an Azure Load Test resource, an Azure KeyVault, an Azure Database for PostgreSQL Flexible Server with a replica and a User Assigned Managed Identity to access KeyVault from the load test.
The load test uses an Apache JMeter script to test the database.
User credentials and JMeter script parameters are stored in the KeyVault.

## Files

- `main.bicep`: Main template that creates a resource group and deploys all resources (subscription scope)
- `resources.bicep`: Module that deploys all resources within the resource group
- `parameters.json`: Parameters file for customizing deployments

## Deployment

### Using the Makefile

The project includes a Makefile to simplify the deployment process:

```bash
# Show available commands
make help

# Login to Azure
make login

# Set the subscription
make set-subscription SUBSCRIPTION_ID=your-subscription-id

# Validate the Bicep template
make validate

# Lint the Bicep template
make lint

# Perform a what-if analysis (preview changes)
make what-if SUBSCRIPTION_ID=your-subscription-id

# Deploy the template
make deploy SUBSCRIPTION_ID=your-subscription-id
```

### Manual Deployment

To deploy manually:

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription <subscription-id>

# Deploy the Bicep template at subscription scope
az deployment sub create \
  --location northeurope \
  --template-file main.bicep \
  --parameters parameters.json
```

## Resources Created

- Resource Group
- Azure Load Test resource
- User Assigned Managed Identity
- Key Vault with the Managed Identity assigned as Key Vault Administrator
