variable "kubernetes_catalog_namespace" {
  type        = string
  description = "The Kubernetes namespace to use for the catalog"
}

variable "kubernetes_ingress_base_host" {
  type        = string
  description = "The base host upon which to build the module Ingress subdomains"
}