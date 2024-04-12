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

variable "minio_tenant_servers_num" {
  type        = number
  description = "The number of servers/pods the MinIO tenant will use"
}

variable "minio_tenant_volumes_per_server_num" {
  type        = number
  description = "The number of volumes per server/pod the MinIO tenant will use"
}

variable "minio_tenant_size_per_volume_gb" {
  type        = number
  description = "The size of each volume for each server/pod MinIO tenant will use (in gigabytes)"
}