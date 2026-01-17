variable "kubernetes_notebooks_namespace" {
  type        = string
  description = "The Kubernetes namespace for the notebooks service"
}

variable "kubernetes_ingress_base_host" {
  type        = string
  description = "The base host upon which to build the module Ingress subdomains"
}

variable "jupyter_image" {
  type        = string
  description = "The Docker image to use for JupyterLab"
  default     = "quay.io/jupyter/scipy-notebook:latest"
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

variable "storage_s3_warehouse" {
  type        = string
  description = "The S3 warehouse location"
}

variable "storage_s3_raw_bucket" {
  type        = string
  description = "The S3 raw data bucket"
}

variable "nessie_uri" {
  type        = string
  description = "The Nessie REST API URI"
}

variable "trino_host" {
  type        = string
  description = "The Trino coordinator host"
}

variable "trino_port" {
  type        = number
  description = "The Trino coordinator port"
  default     = 8080
}

variable "jupyter_storage_size_gb" {
  type        = number
  description = "Size of the persistent storage for Jupyter notebooks"
  default     = 5
}
