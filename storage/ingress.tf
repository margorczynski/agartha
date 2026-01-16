resource "kubernetes_ingress_v1" "ingress_storage_minio_tenant_console" {
  metadata {
    name      = "ingress-storage-minio-tenant-console"
    namespace = var.kubernetes_storage_namespace
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "minio-tenant-console.${var.kubernetes_ingress_base_host}"
      http {
        path {
          backend {
            service {
              name = "${local.tenant_name}-console"
              port {
                number = 9090
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.minio_tenant]
}

resource "kubernetes_ingress_v1" "ingress_storage_minio" {
  metadata {
    name      = "ingress-storage-minio"
    namespace = var.kubernetes_storage_namespace
  }
  spec {
    ingress_class_name = "nginx"
    rule {
      host = "minio.${var.kubernetes_ingress_base_host}"
      http {
        path {
          backend {
            service {
              name = "minio"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.minio_tenant]
}