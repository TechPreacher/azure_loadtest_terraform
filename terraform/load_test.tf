# Note: The Azure Provider doesn't currently have a resource for Azure Load Test configuration
# We'll create the load test resource but the configuration will need to be done manually

# For future reference - might be needed when the provider supports load test configuration
/*
resource "azurerm_load_test_test" "test" {
  name         = var.load_test_test_name
  load_test_id = azurerm_load_test.main.id

  description      = "Load test for PostgreSQL primary and replica databases"
  display_name     = var.load_test_test_name
  test_type        = "JMX"
  engine_instances = var.engine_instances
}
*/

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
    azurerm_load_test.main
  ]
}