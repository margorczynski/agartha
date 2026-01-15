resource "kubernetes_ingress_v1" "ingress_bi_superset" {
  metadata {
    name      = "ingress-bi-superset"
    namespace = var.kubernetes_bi_namespace
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "superset.${var.kubernetes_ingress_base_host}"
      http {
        path {
          backend {
            service {
              name = "superset"
              port {
                number = 8088
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.superset]
}