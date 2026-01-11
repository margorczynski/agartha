resource "kubernetes_config_map_v1" "grafana_datasource_loki" {
  metadata {
    name      = "grafana-datasource-loki"
    namespace = var.kubernetes_monitoring_namespace
    labels = {
      grafana_datasource = "1"
    }
  }

  data = {
    "loki-datasource.yaml" = <<-EOF
      apiVersion: 1
      datasources:
        - name: Loki
          type: loki
          access: proxy
          url: http://loki:3100
          isDefault: false
          editable: true
    EOF
  }

  depends_on = [helm_release.loki_stack]
}
