variable "kubernetes_catalog_namespace" {
  type        = string
  description = "The Kubernetes namespace to use for the catalog"
}

variable "kubernetes_ingress_base_path" {
  type        = string
  description = "The base path upon which to build the module Ingress paths"
}