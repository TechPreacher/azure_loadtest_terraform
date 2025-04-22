variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "load_test_name" {
  description = "The name of the Azure Load Test resource"
  type        = string
}

variable "identity_name" {
  description = "The name of the User Assigned Managed Identity"
  type        = string
}

variable "key_vault_name" {
  description = "The name of the Key Vault"
  type        = string
}

variable "postgres_server_name" {
  description = "The name of the PostgreSQL Flexible Server"
  type        = string
}

variable "postgres_admin_username" {
  description = "The admin username for PostgreSQL"
  type        = string
  sensitive   = true
}

variable "postgres_admin_password" {
  description = "The admin password for PostgreSQL"
  type        = string
  sensitive   = true
}

variable "postgres_database_name" {
  description = "The name of the PostgreSQL database"
  type        = string
  default     = "test"
}

variable "location" {
  description = "Location for all resources"
  type        = string
}

variable "tags" {
  description = "Tags for all resources"
  type        = map(string)
  default     = {}
}

variable "key_vault_sku" {
  description = "SKU name for the Key Vault"
  type        = string
  default     = "standard"
}

variable "soft_delete_retention_days" {
  description = "Soft delete retention period in days"
  type        = number
  default     = 7
}

variable "load_test_test_name" {
  description = "The test name in Azure Load Testing"
  type        = string
  default     = "PostgreSQL Test Timed Load Testing"
}

variable "main_threads" {
  description = "Number of threads for main database operations"
  type        = number
  default     = 10
}

variable "main_loops" {
  description = "Number of loops for main database operations"
  type        = number
  default     = 100
}

variable "replica_threads" {
  description = "Number of threads for replica database operations"
  type        = number
  default     = 40
}

variable "replica_loops" {
  description = "Number of loops for replica database operations"
  type        = number
  default     = 400
}

variable "main_writes_per_minute" {
  description = "Main database writes per minute"
  type        = number
  default     = 120
}

variable "replica_reads_per_minute" {
  description = "Replica database reads per minute"
  type        = number
  default     = 480
}

variable "engine_instances" {
  description = "Number of engine instances for the load test"
  type        = number
  default     = 40
}