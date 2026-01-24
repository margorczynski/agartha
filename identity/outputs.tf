output "keycloak_realm_name" {
  description = "The name of the Keycloak realm"
  value       = "agartha"
}

output "keycloak_grafana_client_id" {
  description = "The client ID for Grafana OAuth"
  value       = "grafana"
}

output "keycloak_grafana_client_secret" {
  description = "The client secret for Grafana OAuth"
  value       = var.grafana_oauth_client_secret
  sensitive   = true
}

output "keycloak_issuer_url" {
  description = "The OIDC issuer URL for Keycloak"
  value       = "http://${local.keycloak_host}/realms/agartha"
}

output "keycloak_auth_url" {
  description = "The OIDC authorization URL (external, for browser redirects)"
  value       = "http://${local.keycloak_host}/realms/agartha/protocol/openid-connect/auth"
}

output "keycloak_token_url" {
  description = "The OIDC token URL (internal, for server-to-server)"
  value       = "http://keycloak.${local.namespace}.svc.cluster.local/realms/agartha/protocol/openid-connect/token"
}

output "keycloak_userinfo_url" {
  description = "The OIDC userinfo URL (internal, for server-to-server)"
  value       = "http://keycloak.${local.namespace}.svc.cluster.local/realms/agartha/protocol/openid-connect/userinfo"
}

output "keycloak_jwks_url" {
  description = "The OIDC JWKS URL (internal, for server-to-server)"
  value       = "http://keycloak.${local.namespace}.svc.cluster.local/realms/agartha/protocol/openid-connect/certs"
}

output "keycloak_api_base_url" {
  description = "The OIDC API base URL (internal, for server-to-server)"
  value       = "http://keycloak.${local.namespace}.svc.cluster.local/realms/agartha/protocol/"
}

output "keycloak_host" {
  description = "The Keycloak hostname"
  value       = local.keycloak_host
}

output "keycloak_superset_client_id" {
  description = "The client ID for Superset OAuth"
  value       = "superset"
}

output "keycloak_superset_client_secret" {
  description = "The client secret for Superset OAuth"
  value       = var.superset_oauth_client_secret
  sensitive   = true
}

output "keycloak_trino_client_id" {
  description = "The client ID for Trino OAuth"
  value       = "trino"
}

output "keycloak_trino_client_secret" {
  description = "The client secret for Trino OAuth"
  value       = var.trino_oauth_client_secret
  sensitive   = true
}
