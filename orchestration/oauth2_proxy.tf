# OAuth2-Proxy for Dagster authentication via Keycloak
resource "helm_release" "dagster_oauth2_proxy" {
  name       = "dagster-oauth2-proxy"
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = "7.12.10"
  namespace  = local.namespace

  values = [
    templatefile("${path.module}/templates/oauth2_proxy_values.tftpl", {
      client_id         = var.dagster_oauth_client_id
      client_secret     = var.dagster_oauth_client_secret
      cookie_secret     = var.dagster_oauth_cookie_secret
      oidc_issuer_url   = var.keycloak_issuer_url
      ingress_base_host = var.kubernetes_ingress_base_host
    })
  ]

  depends_on = [helm_release.dagster]
}
