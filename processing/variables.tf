variable "kubernetes_processing_namespace_base" {
  type        = string
  description = "The Kubernetes base namespace to use for the processing, will create several namespaces for the different clusters"
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
}

variable "trino_cluster_worker_num" {
  type        = number
  description = "The number of worker pods in the Trino cluster"
}

variable "trino_oauth_client_id" {
  type        = string
  description = "The OAuth client ID for Trino authentication with Keycloak"
}

variable "trino_oauth_client_secret" {
  type        = string
  description = "The OAuth client secret for Trino authentication with Keycloak"
  sensitive   = true
}

variable "keycloak_issuer_url" {
  type        = string
  description = "The OIDC issuer URL for Keycloak (external, for token validation)"
}

variable "keycloak_auth_url" {
  type        = string
  description = "The OIDC authorization URL (external, for browser redirects)"
}

variable "keycloak_token_url" {
  type        = string
  description = "The OIDC token URL (internal, for server-to-server)"
}

variable "keycloak_jwks_url" {
  type        = string
  description = "The OIDC JWKS URL (internal, for server-to-server)"
}

variable "keycloak_userinfo_url" {
  type        = string
  description = "The OIDC userinfo URL (internal, for server-to-server)"
}

variable "trino_internal_shared_secret" {
  type        = string
  description = "Shared secret for Trino internal communication when authentication is enabled"
  sensitive   = true
}

variable "spark_allowed_ingress_namespaces" {
  type        = list(string)
  description = "List of namespaces allowed to ingress to spark namespace"
}

variable "flink_allowed_ingress_namespaces" {
  type        = list(string)
  description = "List of namespaces allowed to ingress to flink namespace"
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

variable "trino_allowed_ingress_namespaces" {
  type        = list(string)
  description = "List of namespaces allowed to ingress to trino namespace"
}

variable "spark_operator_resources" {
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

variable "flink_operator_resources" {
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

variable "trino_coordinator_resources" {
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

variable "trino_worker_resources" {
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

variable "trino_coordinator_graceful_shutdown_seconds" {
  type        = number
  description = "Graceful shutdown timeout in seconds for the Trino coordinator to drain in-flight queries"
  default     = 120
}

variable "trino_worker_graceful_shutdown_seconds" {
  type        = number
  description = "Graceful shutdown timeout in seconds for Trino workers to complete running tasks"
  default     = 120
}