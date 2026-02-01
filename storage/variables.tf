variable "kubernetes_storage_namespace" {
  type        = string
  description = "The Kubernetes namespace to use for the storage"
}

variable "kubernetes_ingress_base_host" {
  type        = string
  description = "The base host upon which to build the module Ingress subdomains"
}

variable "s3_access_key" {
  type        = string
  description = "The S3 access key of the initial user to be created"
}

variable "s3_secret_key" {
  type        = string
  description = "The S3 secret key of the initial user to be created"
}

variable "s3_warehouse_bucket_name" {
  type        = string
  description = "The name of the S3 that will be provisioned for the warehouse"
}

variable "s3_raw_bucket_name" {
  type        = string
  description = "The name of the S3 bucket for raw/ingested data"
}

variable "minio_tenant_servers_num" {
  type        = number
  description = "The number of servers/pods the MinIO tenant will use"

  validation {
    condition     = var.minio_tenant_servers_num == 1 || var.minio_tenant_servers_num >= 4
    error_message = "minio_tenant_servers_num must be 1 (single-node dev) or >= 4 (distributed erasure coding). Values 2-3 are invalid for MinIO distributed mode."
  }
}

variable "minio_tenant_volumes_per_server_num" {
  type        = number
  description = "The number of volumes per server/pod the MinIO tenant will use"

  validation {
    condition     = var.minio_tenant_volumes_per_server_num >= 1
    error_message = "minio_tenant_volumes_per_server_num must be at least 1."
  }
}

variable "minio_tenant_size_per_volume_gb" {
  type        = number
  description = "The size of each volume for each server/pod MinIO tenant will use (in gigabytes)"
}

variable "minio_oauth_client_id" {
  type        = string
  description = "The OAuth client ID for MinIO (from Keycloak)"
}

variable "minio_oauth_client_secret" {
  type        = string
  description = "The OAuth client secret for MinIO (from Keycloak)"
  sensitive   = true
}

variable "keycloak_openid_config_url" {
  type        = string
  description = "The OpenID Connect discovery URL for Keycloak"
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
  description = "List of namespaces allowed to ingress to storage namespace"
}

variable "s3_dagster_code_bucket_name" {
  type        = string
  description = "The S3 bucket name for storing Dagster user code"
  default     = "agartha-dagster-code"
}

variable "minio_operator_resources" {
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

variable "minio_tenant_resources" {
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