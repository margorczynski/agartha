resource "kubernetes_ingress_v1" "ingress_catalog_nessie" {
  metadata {
    name      = "ingress-catalog-nessie"
    namespace = var.kubernetes_catalog_namespace
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "nessie.${var.kubernetes_ingress_base_host}"
      http {
        path {
          backend {
            service {
              name = "nessie"
              port {
                number = 19120
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.nessie]
}