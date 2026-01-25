variable "kubernetes_identity_namespace" {
  type        = string
  description = "The Kubernetes namespace for identity services"
  default     = "agartha-identity"
}

variable "kubernetes_ingress_base_host" {
  type        = string
  description = "The base host for ingress access"
}

variable "keycloak_admin_password" {
  type        = string
  description = "The admin password for Keycloak"
  sensitive   = true
}

variable "keycloak_postgres_password" {
  type        = string
  description = "The password for Keycloak PostgreSQL database"
  sensitive   = true
}

variable "keycloak_postgres_storage_size_gb" {
  type        = number
  description = "The storage size for Keycloak PostgreSQL in GB"
  default     = 10
}

variable "keycloak_replicas" {
  type        = number
  description = "Number of Keycloak replicas"
  default     = 1
}

variable "grafana_oauth_client_secret" {
  type        = string
  description = "The client secret for Grafana OAuth integration with Keycloak"
  sensitive   = true
}

variable "superset_oauth_client_secret" {
  type        = string
  description = "The client secret for Superset OAuth integration with Keycloak"
  sensitive   = true
}

variable "trino_oauth_client_secret" {
  type        = string
  description = "The client secret for Trino OAuth integration with Keycloak"
  sensitive   = true
}

variable "minio_oauth_client_secret" {
  type        = string
  description = "The client secret for MinIO OAuth integration with Keycloak"
  sensitive   = true
}
