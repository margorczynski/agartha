resource "kubernetes_network_policy_v1" "flink_namespace_policy" {
  metadata {
    name      = "agartha-processing-flink-netpol"
    namespace = local.flink_namespace
  }

  spec {
    policy_types = ["Ingress"]

    pod_selector {
      match_labels = {}
    }

    dynamic "ingress" {
      for_each = var.flink_allowed_ingress_namespaces
      content {
        from {
          namespace_selector {
            match_labels = {
              "kubernetes.io/metadata.name" = ingress.value
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_namespace_v1.processing_namespace_flink
  ]
}