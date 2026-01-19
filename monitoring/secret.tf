resource "kubernetes_secret_v1" "grafana_admin_credentials" {
  metadata {
    name      = local.grafana_secret_name
    namespace = var.kubernetes_monitoring_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
      "app.kubernetes.io/component"  = "monitoring"
    }
  }

  data = {
    "username" = "admin"
    "password" = var.grafana_admin_password
  }

  depends_on = [
    kubernetes_namespace_v1.monitoring_namespace
  ]
}
