resource "kubernetes_ingress_v1" "ingress_orchestration_dagster" {
  metadata {
    name      = "ingress-orchestration-dagster"
    namespace = local.namespace
    labels    = local.dagster_labels
    annotations = {
      "nginx.ingress.kubernetes.io/proxy-body-size" = "100m"
    }
  }

  spec {
    ingress_class_name = "nginx"
    rule {
      host = "dagster.${var.kubernetes_ingress_base_host}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "dagster-dagster-webserver"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.dagster]
}
