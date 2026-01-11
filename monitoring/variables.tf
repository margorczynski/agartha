variable "kubernetes_monitoring_namespace" {
  type        = string
  description = "The Kubernetes namespace to use for monitoring components"
}

variable "kubernetes_ingress_base_host" {
  type        = string
  description = "The base host upon which to build the module Ingress subdomains"
}

variable "grafana_admin_password" {
  type        = string
  description = "The admin password for Grafana"
  sensitive   = true
}

variable "prometheus_retention_days" {
  type        = number
  description = "Number of days to retain Prometheus metrics data"
  default     = 15
}

variable "prometheus_storage_size_gb" {
  type        = number
  description = "Storage size in GB for Prometheus data"
  default     = 10
}

variable "grafana_storage_size_gb" {
  type        = number
  description = "Storage size in GB for Grafana data"
  default     = 2
}

variable "minio_namespace" {
  type        = string
  description = "The Kubernetes namespace where MinIO is deployed"
}

variable "nessie_namespace" {
  type        = string
  description = "The Kubernetes namespace where Nessie is deployed"
}

variable "trino_namespace" {
  type        = string
  description = "The Kubernetes namespace where Trino is deployed"
}

variable "spark_namespace" {
  type        = string
  description = "The Kubernetes namespace where Spark is deployed"
}

variable "flink_namespace" {
  type        = string
  description = "The Kubernetes namespace where Flink is deployed"
}

variable "loki_storage_size_gb" {
  type        = number
  description = "Storage size in GB for Loki log data"
  default     = 10
}
