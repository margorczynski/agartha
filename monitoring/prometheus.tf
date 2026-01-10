resource "helm_release" "kube_prometheus_stack" {
  namespace        = var.kubernetes_monitoring_namespace
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  create_namespace = false

  values = [
    templatefile("${path.module}/templates/prometheus_values.tftpl", {
      grafana_admin_password     = var.grafana_admin_password
      prometheus_retention_days  = var.prometheus_retention_days
      prometheus_storage_size_gb = var.prometheus_storage_size_gb
      grafana_storage_size_gb    = var.grafana_storage_size_gb
    })
  ]

  depends_on = [kubernetes_namespace_v1.monitoring_namespace]
}
