variable "kubernetes_config_path" {
  type        = string
  description = "The config path for Kubernetes"
}

variable "ingress_host" {
  type        = string
  description = "The host for ingress access"
}

variable "ingress_base_path" {
  type        = string
  description = "The base path for ingress access"
}