resource "kubernetes_ingress_v1" "ingress_monitoring_grafana" {
  metadata {
    name      = "ingress-monitoring-grafana"
    namespace = var.kubernetes_monitoring_namespace
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "grafana.${var.kubernetes_ingress_base_host}"
      http {
        path {
          backend {
            service {
              name = "kube-prometheus-stack-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_ingress_v1" "ingress_monitoring_prometheus" {
  metadata {
    name      = "ingress-monitoring-prometheus"
    namespace = var.kubernetes_monitoring_namespace
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "prometheus.${var.kubernetes_ingress_base_host}"
      http {
        path {
          backend {
            service {
              name = "prometheus-oauth2-proxy"
              port {
                number = 4180
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.prometheus_oauth2_proxy]
}

resource "kubernetes_ingress_v1" "ingress_monitoring_alertmanager" {
  metadata {
    name      = "ingress-monitoring-alertmanager"
    namespace = var.kubernetes_monitoring_namespace
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "alertmanager.${var.kubernetes_ingress_base_host}"
      http {
        path {
          backend {
            service {
              name = "alertmanager-oauth2-proxy"
              port {
                number = 4180
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.alertmanager_oauth2_proxy]
}
