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