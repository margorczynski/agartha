resource "kubernetes_secret_v1" "tls_secret" {
  metadata {
    name      = "tls-secret"
    namespace = var.kubernetes_monitoring_namespace
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = var.tls_certificate
    "tls.key" = var.tls_private_key
  }
}

resource "kubernetes_ingress_v1" "ingress_monitoring_grafana" {
  metadata {
    name      = "ingress-monitoring-grafana"
    namespace = var.kubernetes_monitoring_namespace
    annotations = {
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = ["grafana.${var.kubernetes_ingress_base_host}"]
      secret_name = kubernetes_secret_v1.tls_secret.metadata[0].name
    }
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
    annotations = {
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = ["prometheus.${var.kubernetes_ingress_base_host}"]
      secret_name = kubernetes_secret_v1.tls_secret.metadata[0].name
    }
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
    annotations = {
      "nginx.ingress.kubernetes.io/ssl-redirect"         = "true"
      "nginx.ingress.kubernetes.io/proxy-buffer-size"    = "16k"
      "nginx.ingress.kubernetes.io/proxy-buffers-number" = "4"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = ["alertmanager.${var.kubernetes_ingress_base_host}"]
      secret_name = kubernetes_secret_v1.tls_secret.metadata[0].name
    }
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
