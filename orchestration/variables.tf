variable "kubernetes_orchestration_namespace" {
  type        = string
  description = "The Kubernetes namespace to use for the orchestration components"
}

variable "kubernetes_ingress_base_host" {
  type        = string
  description = "The base host upon which to build the module Ingress subdomains"
}

variable "storage_s3_warehouse_location" {
  type        = string
  description = "The S3 location of the Agartha warehouse storage"
}

variable "storage_s3_endpoint" {
  type        = string
  description = "The S3 endpoint"
}

variable "storage_s3_access_key" {
  type        = string
  description = "The S3 storage access key"
}

variable "storage_s3_secret_key" {
  type        = string
  description = "The S3 storage secret key"
  sensitive   = true
}

variable "dagster_webserver_replica_num" {
  type        = number
  description = "The number of Dagster webserver replicas"
  default     = 1
}

variable "dagster_postgres_password" {
  type        = string
  description = "The password for the Dagster PostgreSQL database"
  sensitive   = true
}

variable "dagster_run_coordinator_max_concurrent_runs" {
  type        = number
  description = "Maximum number of concurrent pipeline runs"
  default     = 10
}

variable "spark_namespace" {
  type        = string
  description = "The Kubernetes namespace where Spark operator is deployed"
}

variable "flink_namespace" {
  type        = string
  description = "The Kubernetes namespace where Flink operator is deployed"
}

variable "dagster_user_code_image" {
  type        = string
  description = "Docker image for Dagster user code deployment (must include dlt dependencies)"
  default     = "docker.io/dagster/dagster-k8s:1.12.11"
}

variable "github_access_token" {
  type        = string
  description = "GitHub personal access token for higher API rate limits (optional)"
  sensitive   = true
  default     = ""
}

# Keycloak OAuth integration for Dagster
variable "dagster_oauth_client_id" {
  type        = string
  description = "The OAuth client ID for Dagster"
}

variable "dagster_oauth_client_secret" {
  type        = string
  description = "The OAuth client secret for Dagster"
  sensitive   = true
}

variable "dagster_oauth_cookie_secret" {
  type        = string
  description = "The cookie secret for OAuth2-Proxy session encryption. Must be exactly 16, 24, or 32 characters. Generate with: openssl rand -hex 16"
  sensitive   = true
}

variable "keycloak_issuer_url" {
  type        = string
  description = "The OIDC issuer URL for Keycloak"
}

variable "keycloak_auth_url" {
  type        = string
  description = "The Keycloak OIDC authorization URL (external, for browser redirects)"
}

variable "keycloak_token_url" {
  type        = string
  description = "The Keycloak OIDC token URL (internal, for server-to-server)"
}

variable "keycloak_jwks_url" {
  type        = string
  description = "The Keycloak OIDC JWKS URL (internal, for server-to-server)"
}

variable "tls_certificate" {
  type        = string
  description = "TLS certificate (PEM format)"
}

variable "tls_private_key" {
  type        = string
  description = "TLS private key (PEM format)"
  sensitive   = true
}

variable "allowed_ingress_namespaces" {
  type        = list(string)
  description = "List of namespaces allowed to ingress to orchestration namespace"
}
