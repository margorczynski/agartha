resource "kubernetes_config_map_v1" "grafana_dashboard_data_platform_overview" {
  metadata {
    name      = "grafana-dashboard-data-platform-overview"
    namespace = var.kubernetes_monitoring_namespace
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "data-platform-overview.json" = file("${path.module}/dashboards/data-platform-overview.json")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_config_map_v1" "grafana_dashboard_minio" {
  metadata {
    name      = "grafana-dashboard-minio"
    namespace = var.kubernetes_monitoring_namespace
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "minio.json" = file("${path.module}/dashboards/minio.json")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_config_map_v1" "grafana_dashboard_trino" {
  metadata {
    name      = "grafana-dashboard-trino"
    namespace = var.kubernetes_monitoring_namespace
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "trino.json" = file("${path.module}/dashboards/trino.json")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_config_map_v1" "grafana_dashboard_spark" {
  metadata {
    name      = "grafana-dashboard-spark"
    namespace = var.kubernetes_monitoring_namespace
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "spark.json" = file("${path.module}/dashboards/spark.json")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_config_map_v1" "grafana_dashboard_flink" {
  metadata {
    name      = "grafana-dashboard-flink"
    namespace = var.kubernetes_monitoring_namespace
    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    "flink.json" = file("${path.module}/dashboards/flink.json")
  }

  depends_on = [helm_release.kube_prometheus_stack]
}
