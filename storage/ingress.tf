resource "kubernetes_ingress_v1" "storage_ingress" {
   metadata {
      name      = "storage-ingress"
      namespace = var.kubernetes_storage_namespace
   }
   spec {
      ingress_class_name = "nginx"
      rule {
        http {
         path {
           path = local.operator_console_path
           path_type = "Prefix"
           backend {
             service {
               name = "console"
               port {
                 number = 9090
               }
             }
           }
        }
        path {
           path = local.tenant_console_path
           path_type = "Prefix"
           backend {
             service {
               name = "minio-tenant-console"
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