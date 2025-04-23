subscription_id         = "<your subscription id>"
resource_group_name     = "resource-group-name"
load_test_name         = "loadtest-name"
identity_name          = "user-assigned-identity-name"
key_vault_name         = "keyvaultname"
postgres_server_name   = "postgresservername"
postgres_admin_username = "pgadmin"
postgres_admin_password = "<your custom password>"
postgres_database_name  = "test"
location               = "northeurope"
key_vault_sku          = "standard"
soft_delete_retention_days = 7
load_test_test_name    = "PostgreSQL Test Timed Load Testing"
main_threads           = 10
main_loops             = 100
replica_threads        = 40
replica_loops          = 400
main_writes_per_minute = 120
replica_reads_per_minute = 480
engine_instances       = 4

tags = {
  environment = "dev"
  project     = "sc-tf-test"
}