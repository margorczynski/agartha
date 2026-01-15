resource "kubernetes_deployment_v1" "dagster_user_code" {
  metadata {
    name      = "dagster-agartha-pipelines"
    namespace = local.namespace
    labels = merge(local.dagster_labels, {
      "app.kubernetes.io/component" = "user-code"
    })
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "dagster-user-code"
        "app.kubernetes.io/component" = "agartha-pipelines"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "dagster-user-code"
          "app.kubernetes.io/component" = "agartha-pipelines"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.dagster_sa.metadata[0].name

        container {
          name  = "user-code"
          image = "docker.io/dagster/dagster-k8s:latest"

          port {
            container_port = 3030
            name           = "grpc"
          }

          command = ["dagster", "api", "grpc", "-h", "0.0.0.0", "-p", "3030", "-f", "/opt/dagster/app/definitions.py"]

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.dagster_storage_config.metadata[0].name
            }
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.dagster_spark_config.metadata[0].name
            }
          }

          volume_mount {
            name       = "dagster-code"
            mount_path = "/opt/dagster/app"
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }

          readiness_probe {
            exec {
              command = ["dagster", "api", "grpc-health-check", "-p", "3030"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          liveness_probe {
            exec {
              command = ["dagster", "api", "grpc-health-check", "-p", "3030"]
            }
            initial_delay_seconds = 30
            period_seconds        = 30
          }
        }

        volume {
          name = "dagster-code"
          config_map {
            name = kubernetes_config_map_v1.dagster_user_code.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.dagster,
    kubernetes_config_map_v1.dagster_user_code
  ]
}

resource "kubernetes_service_v1" "dagster_user_code" {
  metadata {
    name      = "dagster-agartha-pipelines"
    namespace = local.namespace
    labels = merge(local.dagster_labels, {
      "app.kubernetes.io/component" = "user-code"
    })
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "dagster-user-code"
      "app.kubernetes.io/component" = "agartha-pipelines"
    }

    port {
      port        = 3030
      target_port = 3030
      name        = "grpc"
    }
  }

  depends_on = [
    kubernetes_deployment_v1.dagster_user_code
  ]
}
