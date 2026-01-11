resource "helm_release" "loki_stack" {
  namespace        = var.kubernetes_monitoring_namespace
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki-stack"
  create_namespace = false

  values = [
    templatefile("${path.module}/templates/loki_values.tftpl", {
      loki_storage_size_gb = var.loki_storage_size_gb
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.monitoring_namespace,
    helm_release.kube_prometheus_stack
  ]
}
