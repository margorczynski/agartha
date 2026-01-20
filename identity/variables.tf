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
