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
  description = "The password for Dagster PostgreSQL database"
  sensitive   = true
}

variable "openbao_data_storage_size_gb" {
  type        = number
  description = "Storage size in GB for OpenBao data"
  default     = 5
}

variable "openbao_ui_enabled" {
  type        = bool
  description = "Enable OpenBao UI access via ingress"
  default     = true
}

variable "openbao_dev_mode" {
  type        = bool
  description = "Run OpenBao in dev mode (no persistence, auto-unsealed)"
  default     = false
}
