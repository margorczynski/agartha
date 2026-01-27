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

# Keycloak OAuth integration variables
variable "superset_oauth_client_id" {
  type        = string
  description = "The OAuth client ID for Superset (from Keycloak)"
}

variable "superset_oauth_client_secret" {
  type        = string
  description = "The OAuth client secret for Superset (from Keycloak)"
  sensitive   = true
}

variable "keycloak_auth_url" {
  type        = string
  description = "The Keycloak OIDC authorization URL (external, for browser redirects)"
}

variable "keycloak_token_url" {
  type        = string
  description = "The Keycloak OIDC token URL (internal, for server-to-server)"
}

variable "keycloak_issuer_url" {
  type        = string
  description = "The Keycloak OIDC issuer URL (external, must match token iss claim)"
}

variable "keycloak_jwks_url" {
  type        = string
  description = "The Keycloak OIDC JWKS URL (internal, for server-to-server)"
}

variable "keycloak_api_base_url" {
  type        = string
  description = "The Keycloak OIDC API base URL (internal, for server-to-server)"
}

variable "allowed_ingress_namespaces" {
  type        = list(string)
  description = "List of namespaces allowed to ingress to bi namespace"
}