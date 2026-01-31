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

variable "catalog_postgres_password" {
  type        = string
  description = "The password for Nessie PostgreSQL catalog database"
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

variable "identity_minio_oauth_client_secret" {
  type        = string
  description = "The client secret for MinIO OAuth integration with Keycloak"
  sensitive   = true
}

variable "identity_jupyterhub_oauth_client_secret" {
  type        = string
  description = "The client secret for JupyterHub OAuth integration with Keycloak"
  sensitive   = true
}

variable "identity_dagster_oauth_client_secret" {
  type        = string
  description = "The client secret for Dagster OAuth integration with Keycloak"
  sensitive   = true
}

variable "orchestration_dagster_oauth_cookie_secret" {
  type        = string
  description = "The cookie secret for Dagster OAuth2-Proxy session encryption. Must be exactly 16, 24, or 32 characters. Generate with: openssl rand -hex 16"
  sensitive   = true
}

variable "identity_prometheus_oauth_client_secret" {
  type        = string
  description = "The client secret for Prometheus OAuth integration with Keycloak"
  sensitive   = true
}

variable "monitoring_prometheus_oauth_cookie_secret" {
  type        = string
  description = "The cookie secret for Prometheus OAuth2-Proxy session encryption. Must be exactly 16, 24, or 32 characters. Generate with: openssl rand -hex 16"
  sensitive   = true
}

variable "identity_alertmanager_oauth_client_secret" {
  type        = string
  description = "The client secret for Alertmanager OAuth integration with Keycloak"
  sensitive   = true
}

variable "monitoring_alertmanager_oauth_cookie_secret" {
  type        = string
  description = "The cookie secret for Alertmanager OAuth2-Proxy session encryption. Must be exactly 16, 24, or 32 characters. Generate with: openssl rand -hex 16"
  sensitive   = true
}

variable "tls_certificate_path" {
  type        = string
  description = "Path to the TLS certificate file (PEM format)"
}

variable "tls_private_key_path" {
  type        = string
  description = "Path to the TLS private key file (PEM format)"
  sensitive   = true
}

variable "backup_s3_bucket_name" {
  type        = string
  description = "The S3 bucket name for storing Velero backups"
  default     = "agartha-backups"
}

variable "backup_schedule" {
  type        = string
  description = "Cron schedule for automated Velero backups"
  default     = "0 2 * * *"
}

variable "backup_retention_days" {
  type        = number
  description = "Number of days to retain Velero backups"
  default     = 7
}

# =============================================================================
# Resource limits
# =============================================================================

variable "storage_minio_operator_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for the MinIO operator"
  default = {
    requests = { cpu = "100m", memory = "256Mi" }
    limits   = { cpu = "500m", memory = "512Mi" }
  }
}

variable "storage_minio_tenant_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for MinIO tenant pool-0"
  default = {
    requests = { cpu = "500m", memory = "1Gi" }
    limits   = { cpu = "2000m", memory = "4Gi" }
  }
}

variable "catalog_nessie_postgres_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for Nessie PostgreSQL"
  default = {
    requests = { cpu = "250m", memory = "256Mi" }
    limits   = { cpu = "500m", memory = "512Mi" }
  }
}

variable "catalog_nessie_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for Nessie"
  default = {
    requests = { cpu = "250m", memory = "512Mi" }
    limits   = { cpu = "500m", memory = "1Gi" }
  }
}

variable "processing_spark_operator_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for the Spark operator controller"
  default = {
    requests = { cpu = "250m", memory = "512Mi" }
    limits   = { cpu = "500m", memory = "512Mi" }
  }
}

variable "processing_flink_operator_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for the Flink operator"
  default = {
    requests = { cpu = "250m", memory = "512Mi" }
    limits   = { cpu = "1000m", memory = "1Gi" }
  }
}

variable "processing_trino_coordinator_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for the Trino coordinator"
  default = {
    requests = { cpu = "1000m", memory = "2Gi" }
    limits   = { cpu = "2000m", memory = "4Gi" }
  }
}

variable "processing_trino_worker_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for Trino workers"
  default = {
    requests = { cpu = "1000m", memory = "2Gi" }
    limits   = { cpu = "2000m", memory = "4Gi" }
  }
}

variable "notebooks_jupyterhub_hub_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for JupyterHub hub"
  default = {
    requests = { cpu = "250m", memory = "512Mi" }
    limits   = { cpu = "500m", memory = "1Gi" }
  }
}

variable "notebooks_jupyterhub_proxy_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for JupyterHub proxy"
  default = {
    requests = { cpu = "100m", memory = "256Mi" }
    limits   = { cpu = "500m", memory = "512Mi" }
  }
}

variable "bi_superset_node_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for Superset webserver nodes"
  default = {
    requests = { cpu = "250m", memory = "512Mi" }
    limits   = { cpu = "1000m", memory = "2Gi" }
  }
}

variable "bi_superset_worker_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for Superset workers"
  default = {
    requests = { cpu = "250m", memory = "512Mi" }
    limits   = { cpu = "1000m", memory = "2Gi" }
  }
}

variable "bi_superset_postgres_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for Superset PostgreSQL"
  default = {
    requests = { cpu = "250m", memory = "256Mi" }
    limits   = { cpu = "500m", memory = "512Mi" }
  }
}

variable "bi_superset_redis_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for Superset Redis"
  default = {
    requests = { cpu = "50m", memory = "64Mi" }
    limits   = { cpu = "200m", memory = "256Mi" }
  }
}

variable "monitoring_prometheus_server_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for the Prometheus server"
  default = {
    requests = { cpu = "500m", memory = "1Gi" }
    limits   = { cpu = "2000m", memory = "4Gi" }
  }
}

variable "monitoring_grafana_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for Grafana"
  default = {
    requests = { cpu = "100m", memory = "256Mi" }
    limits   = { cpu = "500m", memory = "512Mi" }
  }
}

variable "monitoring_alertmanager_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for Alertmanager"
  default = {
    requests = { cpu = "50m", memory = "64Mi" }
    limits   = { cpu = "200m", memory = "256Mi" }
  }
}

variable "monitoring_loki_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for Loki"
  default = {
    requests = { cpu = "250m", memory = "256Mi" }
    limits   = { cpu = "500m", memory = "1Gi" }
  }
}

variable "monitoring_promtail_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for Promtail"
  default = {
    requests = { cpu = "50m", memory = "64Mi" }
    limits   = { cpu = "200m", memory = "256Mi" }
  }
}

variable "identity_keycloak_postgres_resources" {
  type = object({
    requests = object({ cpu = string, memory = string })
    limits   = object({ cpu = string, memory = string })
  })
  description = "Resource requests and limits for Keycloak PostgreSQL"
  default = {
    requests = { cpu = "250m", memory = "256Mi" }
    limits   = { cpu = "500m", memory = "512Mi" }
  }
}