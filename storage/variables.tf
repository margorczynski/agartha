variable "kubernetes_config_path" {
  type        = string
  description = "The config path for Kubernetes"
}

variable "kubernetes_storage_namespace" {
  type        = string
  description = "The Kubernetes namespace to use for storage"
}

variable "kubernetes_ingress_base_path" {
  type        = string
  description = "The base path upon which to build the module Ingress paths"
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