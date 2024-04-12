resource "kubernetes_ingress_v1" "ingress_processing_trino" {
   metadata {
      name      = "ingress-processing-trino"
      namespace = local.trino_namespace
   }
   spec {
      ingress_class_name = "nginx"
      rule {
        host = "trino.${var.kubernetes_ingress_base_host}"
        http {
         path {
           path = "/"
           path_type = "Prefix"
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

  depends_on = [ helm_release.trino ]
}