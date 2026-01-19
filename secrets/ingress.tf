resource "kubernetes_ingress_v1" "ingress_secrets_openbao" {
  metadata {
    name      = "ingress-secrets-openbao"
    namespace = var.kubernetes_secrets_namespace
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "openbao.${var.kubernetes_ingress_base_host}"
      http {
        path {
          backend {
            service {
              name = "openbao"
              port {
                number = 8200
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.openbao]
}
