# Azure Load Test for Azure Database for PostgreSQL Flexible Server with Replica

This project uses Terraform to deploy Azure Load Test resources and includes a Python application for database management.
The configuration deploys an Azure Load Test resource, an Azure KeyVault, an Azure Database for PostgreSQL Flexible Server with a replica, and a User Assigned Managed Identity to access KeyVault from the load test.
The load test uses an Apache JMeter script to test the database.
User credentials and JMeter script parameters are stored in the KeyVault.

## Project Structure

### Infrastructure as Code

- `terraform/`: Contains the Terraform configuration for deploying all infrastructure
- `terraform/README.md`: Detailed instructions for the Terraform configuration
- `load_test_artifacts/`: Contains JMeter script and PostgreSQL JDBC driver for load testing

### Python Database Application

The project includes a Python application in the `create_database` directory that helps create and populate the PostgreSQL database:

- `create_database/database_setup.py`: Python script to initialize and populate the PostgreSQL database
- `create_database/verify_replication.py`: Python script to verify replication between primary and replica databases
- `create_database/streamlit_app.py`: Streamlit web application to view and edit data in the database
- `create_database/data/sample_data.json`: Sample data for database initialization

## Deployment

### Using the Makefile

The project includes a Makefile to simplify the Terraform deployment process:

```bash
# Show available commands
make help

# Login to Azure
make login

# Set the subscription
make set-subscription SUBSCRIPTION_ID=your-subscription-id

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

### Manual Terraform Commands

If you prefer not to use the Makefile, you can run the Terraform commands directly:

```bash
# Initialize Terraform
cd terraform
terraform init

# Validate configuration
terraform validate

# Review deployment plan
terraform plan -var="subscription_id=your-subscription-id"

# Apply the configuration
terraform apply -var="subscription_id=your-subscription-id"

# Destroy resources when done
terraform destroy -var="subscription_id=your-subscription-id"
```

## Python Application Setup

The Python application is built using Poetry for dependency management.

### Setup the Python Environment

```bash
# Install dependencies using Poetry
poetry install

# Activate the virtual environment
poetry shell
```

### Configure Database Connection

Create a `.env` file in the `create_database` directory with your PostgreSQL connection details:

```
# Azure Subscription Settings
AZURE_SUBSCRIPTION_ID=your-subscription-id
AZURE_RESOURCE_GROUP=your-resource-group

# Primary PostgreSQL server connection details
AZURE_POSTGRES_PRIMARY_HOST=your-server.postgres.database.azure.com
AZURE_POSTGRES_PRIMARY_USER=your-username@your-server
AZURE_POSTGRES_PRIMARY_PASSWORD=your-password
AZURE_POSTGRES_PRIMARY_DB=test

# Replica PostgreSQL server connection details (for verify_replication.py)
AZURE_POSTGRES_REPLICA_HOST=your-replica-server.postgres.database.azure.com
AZURE_POSTGRES_REPLICA_USER=your-username@your-replica-server
AZURE_POSTGRES_REPLICA_PASSWORD=your-password
AZURE_POSTGRES_REPLICA_DB=test

# SSL mode for all connections
AZURE_POSTGRES_SSL_MODE=require

# For the Streamlit app
AZURE_POSTGRES_HOST=your-server.postgres.database.azure.com
AZURE_POSTGRES_USER=your-username@your-server
AZURE_POSTGRES_PASSWORD=your-password
AZURE_POSTGRES_DB=test
```

For the replication verification script, if replica details are not provided, it will try to derive them from the primary server details by appending "repl" to the hostname.

### Running the Application

You can run the applications using the VS Code launch profiles or directly from the command line:

```bash
# Initialize and populate the database
python create_database/database_setup.py

# Verify replication between primary and replica databases
python create_database/verify_replication.py

# Start the Streamlit web application
streamlit run create_database/streamlit_app.py
```

### VS Code Launch Profiles

The project includes three VS Code launch profiles:

1. **DB Initialization** - Runs the database setup script to initialize and populate the database
2. **Verify Replication** - Checks if data is properly replicated between primary and replica databases
3. **Streamlit App** - Launches the Streamlit web application for viewing and editing data

## Resources Created

- Resource Group
- Azure Load Test resource
- Azure Load Test configuration with JMeter
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

## Load Testing Configuration

The deployment includes a JMeter-based load test configuration with:

- Separate thread groups for primary write operations and replica read operations
- Configurable thread counts, loops, and operations per minute
- PostgreSQL JDBC driver for database connectivity
- Reference to Key Vault secrets for database credentials
- User Assigned Managed Identity for secure Key Vault access
- Monitoring of PostgreSQL server metrics during test execution

### Manual Steps for Load Testing

After deploying the infrastructure:

1. Navigate to the Azure Portal → Azure Load Testing → [Load Test Name] → Tests
2. Click on the test configuration
3. Click 'Edit' and manually upload the following files:
   - JMeter script: `load_test_artifacts/jmeter_script.jmx`
   - PostgreSQL JDBC driver: `load_test_artifacts/postgresql-42.7.5.jar` (in the 'Additional Files' section)
4. Save the test configuration
5. Run the test and monitor the performance of both primary and replica servers

## Post-Deployment Steps

The Terraform deployment automatically configures the User Assigned Managed Identity as a Microsoft Entra administrator for the PostgreSQL server. No manual steps are required for the Entra admin configuration.