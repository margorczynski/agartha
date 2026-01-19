variable "kubernetes_secrets_namespace" {
  type        = string
  description = "The Kubernetes namespace to use for secrets management"
}

variable "kubernetes_ingress_base_host" {
  type        = string
  description = "The base host upon which to build the module Ingress subdomains"
}

variable "openbao_data_storage_size_gb" {
  type        = number
  description = "Storage size in GB for OpenBao data"
  default     = 5
}

variable "openbao_ui_enabled" {
  type        = bool
  description = "Enable OpenBao UI access via ingress"
  default     = true
}

variable "openbao_dev_mode" {
  type        = bool
  description = "Run OpenBao in dev mode (no persistence, auto-unsealed)"
  default     = false
}
