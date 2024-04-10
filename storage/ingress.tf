resource "kubernetes_ingress_v1" "storage_ingress_operator_console" {
   metadata {
      name      = "storage-ingress-operator-console"
      namespace = var.kubernetes_storage_namespace
   }
   spec {
      ingress_class_name = "nginx"
      rule {
        http {
         path {
           path = "${local.operator_console_path}"
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
      }
    }
  }

  depends_on = [ helm_release.minio_operator ]
}

resource "kubernetes_ingress_v1" "storage_ingress_tenant_console" {
   metadata {
      name      = "storage-ingress-tenant-console"
      namespace = var.kubernetes_storage_namespace
      annotations = {
        "nginx.ingress.kubernetes.io/rewrite-target" = "/$1"
      }
   }
   spec {
      ingress_class_name = "nginx"
      rule {
        http {
          path {
            path = "${local.tenant_console_path}/(.*)"
            path_type = "Prefix"
            backend {
              service {
                name = "minio-tenant-console"
                port {
                  number = 9090
                }
              }
            }
          }
      }
    }
  }

  depends_on = [ helm_release.minio_tenant ]
}