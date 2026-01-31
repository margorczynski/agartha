variable "kubernetes_config_path" {
  type        = string
  description = "The config path for Kubernetes"
}

variable "ingress_host" {
  type        = string
  description = "The host for ingress access"
}

variable "storage_s3_warehouse_bucket_name" {
  type        = string
  description = "The S3 bucket name to be created and used for storing the data"
}

variable "storage_s3_raw_bucket_name" {
  type        = string
  description = "The S3 bucket name to be created and used for raw/ingested data"
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