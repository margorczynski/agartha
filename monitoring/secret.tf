resource "kubernetes_secret_v1" "grafana_admin_credentials" {
  metadata {
    name      = "grafana-admin-credentials"
    namespace = var.kubernetes_monitoring_namespace
  }

  data = {
    admin-user     = "admin"
    admin-password = var.grafana_admin_password
  }

  depends_on = [
    kubernetes_namespace_v1.monitoring_namespace
  ]
}

resource "kubernetes_secret_v1" "prometheus_oauth2_proxy_secret" {
  metadata {
    name      = "prometheus-oauth2-proxy-secret"
    namespace = var.kubernetes_monitoring_namespace
  }

  data = {
    client-id     = var.prometheus_oauth_client_id
    client-secret = var.prometheus_oauth_client_secret
    cookie-secret = var.prometheus_oauth_cookie_secret
  }

  depends_on = [
    kubernetes_namespace_v1.monitoring_namespace
  ]
}

resource "kubernetes_secret_v1" "alertmanager_oauth2_proxy_secret" {
  metadata {
    name      = "alertmanager-oauth2-proxy-secret"
    namespace = var.kubernetes_monitoring_namespace
  }

  data = {
    client-id     = var.alertmanager_oauth_client_id
    client-secret = var.alertmanager_oauth_client_secret
    cookie-secret = var.alertmanager_oauth_cookie_secret
  }

  depends_on = [
    kubernetes_namespace_v1.monitoring_namespace
  ]
}
