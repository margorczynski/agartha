variable "kubernetes_bi_namespace" {
  type        = string
  description = "The Kubernetes namespace to use for BI"
}

variable "kubernetes_ingress_base_host" {
  type        = string
  description = "The base host upon which to build the module Ingress subdomains"
}

variable "superset_node_replica_num" {
  type        = number
  description = "Number of Superset node replicas"
}

variable "superset_worker_replica_num" {
  type        = number
  description = "Number of Superset worker replicas"
}