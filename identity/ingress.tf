resource "kubernetes_ingress_v1" "keycloak_ingress" {
  metadata {
    name      = "keycloak-ingress"
    namespace = local.namespace
    annotations = {
      "nginx.ingress.kubernetes.io/proxy-body-size"      = "10m"
      "nginx.ingress.kubernetes.io/proxy-buffer-size"    = "128k"
      "nginx.ingress.kubernetes.io/proxy-buffers-number" = "4"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      host = local.keycloak_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "keycloak"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace_v1.identity_namespace,
    helm_release.keycloak
  ]
}
