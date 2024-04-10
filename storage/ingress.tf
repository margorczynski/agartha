resource "kubernetes_ingress_v1" "example" {
  wait_for_load_balancer = true
   metadata {
      name        = "storage-ingress"
      namespace   = var.kubernetes_storage_namespace
   }
   spec {
      ingress_class_name = "nginx"
      rule {
        host = "agartha.local"
        http {
         path {
           path = "/*"
           backend {
             service {
               name = "console"
               port {
                 number = 9443
               }
             }
           }
        }
      }
    }
  }
}