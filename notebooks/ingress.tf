resource "kubernetes_ingress_v1" "jupyter" {
  metadata {
    name      = "jupyter-ingress"
    namespace = local.namespace
    labels    = local.jupyter_labels

    annotations = {
      "nginx.ingress.kubernetes.io/proxy-body-size"       = "100m"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"    = "3600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"    = "3600"
      # WebSocket support for Jupyter
      "nginx.ingress.kubernetes.io/proxy-http-version"    = "1.1"
      "nginx.ingress.kubernetes.io/upstream-hash-by"      = "$request_uri"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = local.jupyter_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.jupyter.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service_v1.jupyter]
}
