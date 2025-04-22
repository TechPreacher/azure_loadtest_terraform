# Load Test configuration
resource "azurerm_load_test_url" "test" {
  name         = var.load_test_test_name
  load_test_id = azurerm_load_test.main.id

  description    = "Load test for PostgreSQL primary and replica databases"
  display_name   = var.load_test_test_name
  test_type      = "JMX"
  engine_instances = var.engine_instances

  # Note: Terraform doesn't natively support file uploads for load tests
  # You'll need to manually upload the JMeter script and JDBC driver
  # after applying the Terraform configuration

  # Environment variables
  environment_variables = {
    main_threads          = var.main_threads
    main_loops            = var.main_loops
    main_database         = "jdbc:postgresql://${azurerm_postgresql_flexible_server.primary.fqdn}:5432/${var.postgres_database_name}"
    replica_threads       = var.replica_threads
    replica_loops         = var.replica_loops
    replica_database      = "jdbc:postgresql://${azurerm_postgresql_flexible_server.replica.fqdn}:5432/${var.postgres_database_name}"
    main_writes_per_minute = var.main_writes_per_minute
    replica_reads_per_minute = var.replica_reads_per_minute
  }

  # Secrets from Key Vault
  secrets = {
    mainuser = {
      type  = "AKV_SECRET_URI"
      value = "${azurerm_key_vault.main.vault_uri}secrets/postgres-username"
    }
    mainpassword = {
      type  = "AKV_SECRET_URI"
      value = "${azurerm_key_vault.main.vault_uri}secrets/postgres-password"
    }
    replicauser = {
      type  = "AKV_SECRET_URI"
      value = "${azurerm_key_vault.main.vault_uri}secrets/postgres-username"
    }
    replicapassword = {
      type  = "AKV_SECRET_URI"
      value = "${azurerm_key_vault.main.vault_uri}secrets/postgres-password"
    }
  }

  # Identity configuration
  secrets_configuration {
    key_vault_id = azurerm_key_vault.main.id
    identity_id  = azurerm_user_assigned_identity.main.id
  }

  # Pass/Fail criteria
  pass_fail_criteria {
    pass_fail_metric {
      name      = "totalRequests"
      aggregate = "avg"
      client_metric = "request_count"
      condition = ">="
      value     = 1
    }
    pass_fail_metric {
      name      = "averageResponseTime"
      aggregate = "avg"
      client_metric = "response_time_ms"
      condition = "<="
      value     = 5000
    }
    pass_fail_metric {
      name      = "requestsPerSec"
      aggregate = "avg"
      client_metric = "requests_per_sec"
      condition = ">="
      value     = 1
    }
  }
}

# Run post-deployment message about manual steps
resource "null_resource" "manual_steps_reminder" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "===== IMPORTANT: Manual actions required =====" 
      echo "After deployment, you need to manually:"
      echo ""
      echo "1. Upload files to the Load Test:"
      echo "   a. Navigate to Azure Portal > Load Testing > ${var.load_test_name} > Tests"
      echo "   b. Click on the test '${var.load_test_test_name}'"
      echo "   c. Click 'Edit' and upload:"
      echo "      - JMeter script: load_test_artifacts/jmeter_script.jmx"
      echo "      - JDBC driver: load_test_artifacts/postgresql-42.7.5.jar (in 'Additional Files')"
      echo ""
      echo "Note: The User Assigned Managed Identity has been automatically configured"
      echo "as a Microsoft Entra administrator for the PostgreSQL server."
      echo "========================================"
    EOT
  }

  depends_on = [
    azurerm_postgresql_flexible_server.primary,
    azurerm_postgresql_flexible_server.replica,
    azurerm_load_test_url.test
  ]
}