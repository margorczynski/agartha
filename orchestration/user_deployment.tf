resource "kubernetes_deployment_v1" "dagster_user_code" {
  for_each = var.dagster_user_code_deployments

  metadata {
    name      = "dagster-${each.key}"
    namespace = local.namespace
    labels = merge(local.dagster_labels, {
      "app.kubernetes.io/component" = "user-code"
      "app.kubernetes.io/instance"  = each.key
    })
  }

  spec {
    replicas = each.value.replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name"     = "dagster-user-code"
        "app.kubernetes.io/instance" = each.key
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"     = "dagster-user-code"
          "app.kubernetes.io/instance" = each.key
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.dagster_sa.metadata[0].name

        container {
          name  = "user-code"
          image = each.value.image

          port {
            container_port = 3030
            name           = "grpc"
          }

          command = ["/bin/sh", "-c"]
          args = [
            "python /opt/dagster/scripts/sync_code.py && dagster api grpc -h 0.0.0.0 -p 3030 -f /opt/dagster/deployments/${each.key}/definitions.py"
          ]

          env {
            name  = "DAGSTER_CODE_BUCKET"
            value = var.dagster_code_bucket
          }
          env {
            name  = "DAGSTER_CODE_PATH"
            value = each.value.code_path
          }
          env {
            name  = "DAGSTER_CODE_DEST"
            value = "/opt/dagster/deployments/${each.key}"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.dagster_storage_config.metadata[0].name
            }
          }

          env_from {
            secret_ref {
              name = kubernetes_secret_v1.dagster_s3_credentials.metadata[0].name
            }
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.dagster_spark_config.metadata[0].name
            }
          }

          volume_mount {
            name       = "sync-script"
            mount_path = "/opt/dagster/scripts"
            read_only  = true
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
            initial_delay_seconds = 120
            period_seconds        = 10
          }

          liveness_probe {
            exec {
              command = ["dagster", "api", "grpc-health-check", "-p", "3030"]
            }
            initial_delay_seconds = 120
            period_seconds        = 30
          }
        }

        volume {
          name = "sync-script"
          config_map {
            name = kubernetes_config_map_v1.dagster_code_sync_script.metadata[0].name
          }
        }

        volume {
          name = "dlt-state"
          empty_dir {}
        }
      }
    }
  }

  depends_on = [
    helm_release.dagster
  ]
}

resource "kubernetes_service_v1" "dagster_user_code" {
  for_each = var.dagster_user_code_deployments

  metadata {
    name      = "dagster-${each.key}"
    namespace = local.namespace
    labels = merge(local.dagster_labels, {
      "app.kubernetes.io/component" = "user-code"
      "app.kubernetes.io/instance"  = each.key
    })
  }

  spec {
    selector = {
      "app.kubernetes.io/name"     = "dagster-user-code"
      "app.kubernetes.io/instance" = each.key
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

moved {
  from = kubernetes_deployment_v1.dagster_user_code
  to   = kubernetes_deployment_v1.dagster_user_code["agartha-pipelines"]
}

moved {
  from = kubernetes_service_v1.dagster_user_code
  to   = kubernetes_service_v1.dagster_user_code["agartha-pipelines"]
}
