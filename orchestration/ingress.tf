resource "kubernetes_secret_v1" "tls_secret" {
  metadata {
    name      = "tls-secret"
    namespace = local.namespace
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = var.tls_certificate
    "tls.key" = var.tls_private_key
  }
}

resource "kubernetes_ingress_v1" "ingress_orchestration_dagster" {
  metadata {
    name      = "ingress-orchestration-dagster"
    namespace = local.namespace
    labels    = local.dagster_labels
    annotations = {
      "nginx.ingress.kubernetes.io/ssl-redirect"         = "true"
      "nginx.ingress.kubernetes.io/proxy-body-size"      = "100m"
      "nginx.ingress.kubernetes.io/proxy-buffer-size"    = "16k"
      "nginx.ingress.kubernetes.io/proxy-buffers-number" = "4"
    }
  }

  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = ["dagster.${var.kubernetes_ingress_base_host}"]
      secret_name = kubernetes_secret_v1.tls_secret.metadata[0].name
    }
    rule {
      host = "dagster.${var.kubernetes_ingress_base_host}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "dagster-oauth2-proxy"
              port {
                number = 4180
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.dagster_oauth2_proxy]
}
