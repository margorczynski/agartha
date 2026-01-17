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

variable "nessie_uri" {
  type        = string
  description = "The Nessie Iceberg REST catalog URI"
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
