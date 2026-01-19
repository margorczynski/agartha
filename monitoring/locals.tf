locals {
  namespace = var.kubernetes_monitoring_namespace

  grafana_secret_name = "grafana-admin-credentials"

  labels = {
    "app.kubernetes.io/name"       = "monitoring"
    "app.kubernetes.io/component"  = "monitoring"
    "app.kubernetes.io/part-of"    = "agartha"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}
