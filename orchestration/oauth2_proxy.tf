# OAuth2-Proxy for Dagster authentication via Keycloak
resource "helm_release" "dagster_oauth2_proxy" {
  name       = "dagster-oauth2-proxy"
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = "7.12.10"
  namespace  = local.namespace

  values = [
    templatefile("${path.module}/templates/oauth2_proxy_values.tftpl", {
      existing_secret    = kubernetes_secret_v1.dagster_oauth2_proxy_secret.metadata[0].name
      oidc_issuer_url    = var.keycloak_issuer_url
      keycloak_auth_url  = var.keycloak_auth_url
      keycloak_token_url = var.keycloak_token_url
      keycloak_jwks_url  = var.keycloak_jwks_url
      ingress_base_host  = var.kubernetes_ingress_base_host
    })
  ]

  depends_on = [
    helm_release.dagster,
    kubernetes_secret_v1.dagster_oauth2_proxy_secret
  ]
}
