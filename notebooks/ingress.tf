resource "kubernetes_ingress_v1" "jupyterhub" {
  metadata {
    name      = "jupyterhub-ingress"
    namespace = local.namespace
    labels    = local.jupyterhub_labels

    annotations = {
      "nginx.ingress.kubernetes.io/proxy-body-size"     = "100m"
      "nginx.ingress.kubernetes.io/proxy-read-timeout"  = "3600"
      "nginx.ingress.kubernetes.io/proxy-send-timeout"  = "3600"
      "nginx.ingress.kubernetes.io/proxy-http-version"  = "1.1"
      "nginx.ingress.kubernetes.io/upstream-hash-by"    = "$request_uri"
      "nginx.ingress.kubernetes.io/websocket-services"  = "proxy-public"
      "nginx.ingress.kubernetes.io/affinity"            = "cookie"
      "nginx.ingress.kubernetes.io/session-cookie-name" = "jupyterhub-session"
      "nginx.ingress.kubernetes.io/session-cookie-path" = "/"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = local.jupyterhub_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "proxy-public"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.jupyterhub]
}
