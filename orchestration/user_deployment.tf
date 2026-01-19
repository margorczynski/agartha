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
          image = var.dagster_user_code_image

          port {
            container_port = 3030
            name           = "grpc"
          }

          # Install dlt at startup and run the gRPC server
          command = ["/bin/sh", "-c"]
          args = [<<-EOT
            pip install --no-cache-dir "dlt[filesystem]>=1.0.0" "s3fs>=2024.2.0" "pyarrow>=15.0.0" "boto3" && \
            dagster api grpc -h 0.0.0.0 -p 3030 -f /opt/dagster/app/definitions.py
          EOT
          ]

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

          # dlt-specific environment variables
          env {
            name  = "DLT_S3_BUCKET"
            value = "agartha-raw"
          }

          # Optional GitHub token for higher rate limits
          dynamic "env" {
            for_each = var.github_access_token != "" ? [1] : []
            content {
              name  = "GITHUB_ACCESS_TOKEN"
              value = var.github_access_token
            }
          }

          volume_mount {
            name       = "dagster-code"
            mount_path = "/opt/dagster/app"
          }

          volume_mount {
            name       = "dlt-state"
            mount_path = "/tmp/dlt_pipelines"
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
            initial_delay_seconds = 60 # Increased for pip install time
            period_seconds        = 10
          }

          liveness_probe {
            exec {
              command = ["dagster", "api", "grpc-health-check", "-p", "3030"]
            }
            initial_delay_seconds = 60 # Increased for pip install time
            period_seconds        = 30
          }
        }

        volume {
          name = "dagster-code"
          config_map {
            name = kubernetes_config_map_v1.dagster_user_code.metadata[0].name
          }
        }

        # Persistent volume for dlt pipeline state (incremental loading)
        volume {
          name = "dlt-state"
          empty_dir {}
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
