# Self-signed TLS certificate for Trino
# Required for OAuth2 web UI which needs X-Forwarded-Proto: https
resource "tls_private_key" "trino_tls" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "trino_tls" {
  private_key_pem = tls_private_key.trino_tls.private_key_pem

  subject {
    common_name  = "trino.${var.kubernetes_ingress_base_host}"
    organization = "Agartha Data Platform"
  }

  dns_names = [
    "trino.${var.kubernetes_ingress_base_host}",
    "*.${var.kubernetes_ingress_base_host}"
  ]

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

resource "kubernetes_secret_v1" "trino_tls_secret" {
  metadata {
    name      = "trino-tls-secret"
    namespace = local.trino_namespace
  }

  type = "kubernetes.io/tls"

  data = {
    "tls.crt" = tls_self_signed_cert.trino_tls.cert_pem
    "tls.key" = tls_private_key.trino_tls.private_key_pem
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
      secret_name = kubernetes_secret_v1.trino_tls_secret.metadata[0].name
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

  depends_on = [helm_release.trino, kubernetes_secret_v1.trino_tls_secret]
}