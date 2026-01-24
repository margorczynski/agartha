variable "kubernetes_config_path" {
  type        = string
  description = "The config path for Kubernetes"
}

variable "ingress_host" {
  type        = string
  description = "The host for ingress access"
}

variable "storage_s3_access_key" {
  type        = string
  description = "The S3 access key to be created and used for the root user"
}

variable "storage_s3_secret_key" {
  type        = string
  description = "The S3 secret key to be created and used for the root user"
}

variable "storage_s3_warehouse_bucket_name" {
  type        = string
  description = "The S3 bucket name to be created and used for storing the data"
}

variable "storage_s3_raw_bucket_name" {
  type        = string
  description = "The S3 bucket name to be created and used for raw/ingested data"
}

variable "monitoring_grafana_admin_password" {
  type        = string
  description = "The admin password for Grafana"
  sensitive   = true
}

variable "orchestration_dagster_postgres_password" {
  type        = string
  description = "The password for the Dagster PostgreSQL database"
  sensitive   = true
}

variable "identity_keycloak_admin_password" {
  type        = string
  description = "The admin password for Keycloak"
  sensitive   = true
}

variable "identity_keycloak_postgres_password" {
  type        = string
  description = "The password for Keycloak PostgreSQL database. Leave empty to auto-generate."
  sensitive   = true
  default     = ""
}

variable "identity_grafana_oauth_client_secret" {
  type        = string
  description = "The client secret for Grafana OAuth integration with Keycloak"
  sensitive   = true
}

variable "identity_superset_oauth_client_secret" {
  type        = string
  description = "The client secret for Superset OAuth integration with Keycloak"
  sensitive   = true
}

variable "identity_trino_oauth_client_secret" {
  type        = string
  description = "The client secret for Trino OAuth integration with Keycloak"
  sensitive   = true
}

variable "processing_trino_internal_shared_secret" {
  type        = string
  description = "Shared secret for Trino internal communication when authentication is enabled"
  sensitive   = true
}