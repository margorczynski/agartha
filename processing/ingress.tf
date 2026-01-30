resource "kubernetes_secret_v1" "tls_secret" {
  metadata {
    name      = "tls-secret"
    namespace = local.trino_namespace
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = var.tls_certificate
    "tls.key" = var.tls_private_key
  }
}

resource "kubernetes_ingress_v1" "ingress_processing_trino" {
  metadata {
    name      = "ingress-processing-trino"
    namespace = local.trino_namespace
    annotations = {
      # Enable SSL redirect to ensure HTTPS is used
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
      # Increase buffer sizes for OAuth tokens which can be large
      "nginx.ingress.kubernetes.io/proxy-buffer-size"    = "16k"
      "nginx.ingress.kubernetes.io/proxy-buffers-number" = "4"
    }
  }
  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = ["trino.${var.kubernetes_ingress_base_host}"]
      secret_name = kubernetes_secret_v1.tls_secret.metadata[0].name
    }
    rule {
      host = "trino.${var.kubernetes_ingress_base_host}"
      http {
        path {
          backend {
            service {
              name = "trino"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.trino, kubernetes_secret_v1.tls_secret]
}
