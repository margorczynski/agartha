# OAuth2-Proxy for Prometheus authentication via Keycloak
resource "helm_release" "prometheus_oauth2_proxy" {
  name       = "prometheus-oauth2-proxy"
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = "7.12.10"
  namespace  = var.kubernetes_monitoring_namespace

  values = [
    templatefile("${path.module}/templates/prometheus_oauth2_proxy_values.tftpl", {
      client_id         = var.prometheus_oauth_client_id
      client_secret     = var.prometheus_oauth_client_secret
      cookie_secret     = var.prometheus_oauth_cookie_secret
      oidc_issuer_url   = var.keycloak_issuer_url
      ingress_base_host = var.kubernetes_ingress_base_host
    })
  ]

  depends_on = [helm_release.kube_prometheus_stack]
}

# OAuth2-Proxy for Alertmanager authentication via Keycloak
resource "helm_release" "alertmanager_oauth2_proxy" {
  name       = "alertmanager-oauth2-proxy"
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = "7.12.10"
  namespace  = var.kubernetes_monitoring_namespace

  values = [
    templatefile("${path.module}/templates/alertmanager_oauth2_proxy_values.tftpl", {
      client_id         = var.alertmanager_oauth_client_id
      client_secret     = var.alertmanager_oauth_client_secret
      cookie_secret     = var.alertmanager_oauth_cookie_secret
      oidc_issuer_url   = var.keycloak_issuer_url
      ingress_base_host = var.kubernetes_ingress_base_host
    })
  ]

  depends_on = [helm_release.kube_prometheus_stack]
}
