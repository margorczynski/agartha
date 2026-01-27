variable "kubernetes_catalog_namespace" {
  type        = string
  description = "The Kubernetes namespace to use for the catalog"
}

variable "kubernetes_ingress_base_host" {
  type        = string
  description = "The base host upon which to build the module Ingress subdomains"
}

variable "storage_s3_endpoint" {
  type        = string
  description = "The S3 endpoint URL for MinIO"
}

variable "storage_s3_access_key" {
  type        = string
  description = "The S3 access key"
}

variable "storage_s3_secret_key" {
  type        = string
  description = "The S3 secret key"
  sensitive   = true
}

variable "storage_s3_warehouse_bucket" {
  type        = string
  description = "The S3 warehouse bucket name"
}

variable "catalog_postgres_password" {
  type        = string
  description = "The PostgreSQL password for Nessie catalog"
  sensitive   = true
}

variable "allowed_ingress_namespaces" {
  type        = list(string)
  description = "List of namespaces allowed to ingress to catalog namespace"
}