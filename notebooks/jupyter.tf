# ConfigMap for example notebooks
resource "kubernetes_config_map_v1" "jupyter_examples" {
  metadata {
    name      = "jupyter-examples"
    namespace = local.namespace
    labels    = local.jupyter_labels
  }

  data = {
    "getting_started.ipynb" = file("${path.module}/examples/getting_started.ipynb")
  }

  depends_on = [kubernetes_namespace_v1.notebooks_namespace]
}

# ConfigMap for environment configuration
resource "kubernetes_config_map_v1" "jupyter_config" {
  metadata {
    name      = "jupyter-config"
    namespace = local.namespace
    labels    = local.jupyter_labels
  }

  data = {
    # Nessie Iceberg REST catalog (S3 credentials managed server-side)
    NESSIE_URI = var.nessie_uri
    TRINO_HOST = var.trino_host
    TRINO_PORT = tostring(var.trino_port)
    # PyIceberg default catalog configuration
    PYICEBERG_CATALOG__DEFAULT__TYPE = "rest"
    PYICEBERG_CATALOG__DEFAULT__URI  = var.nessie_uri
  }

  depends_on = [kubernetes_namespace_v1.notebooks_namespace]
}

# PVC for notebook storage
resource "kubernetes_persistent_volume_claim_v1" "jupyter_storage" {
  metadata {
    name      = "jupyter-storage"
    namespace = local.namespace
    labels    = local.jupyter_labels
  }

  spec {
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "${var.jupyter_storage_size_gb}Gi"
      }
    }
  }

  depends_on = [kubernetes_namespace_v1.notebooks_namespace]
}

# JupyterLab Deployment
resource "kubernetes_deployment_v1" "jupyter" {
  metadata {
    name      = "jupyter"
    namespace = local.namespace
    labels    = local.jupyter_labels
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name"      = "jupyter"
        "app.kubernetes.io/component" = "notebooks"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "jupyter"
          "app.kubernetes.io/component" = "notebooks"
        }
      }

      spec {
        security_context {
          fs_group = 100  # jovyan group
        }

        container {
          name  = "jupyter"
          image = var.jupyter_image

          port {
            container_port = 8888
            name           = "http"
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map_v1.jupyter_config.metadata[0].name
            }
          }

          # Disable authentication for local development
          # In production, configure proper authentication
          env {
            name  = "JUPYTER_TOKEN"
            value = ""
          }

          # Install packages at startup, then start Jupyter
          command = ["/bin/bash", "-c"]
          args = [<<-EOT
            pip install --no-cache-dir \
              "polars>=1.0.0" \
              "pyarrow>=15.0.0" \
              "pyiceberg[s3fs,pyarrow]>=0.7.0" \
              "s3fs>=2024.2.0" \
              "boto3" \
              "trino" \
              "duckdb" \
              "httpx" \
              "plotly" \
              "altair" && \
            exec start-notebook.py \
              --NotebookApp.token='' \
              --NotebookApp.password='' \
              --NotebookApp.allow_origin='*' \
              --NotebookApp.base_url=/
          EOT
          ]

          volume_mount {
            name       = "jupyter-home"
            mount_path = "/home/jovyan"
          }

          volume_mount {
            name       = "examples"
            mount_path = "/home/jovyan/examples"
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "2000m"
              memory = "4Gi"
            }
          }

          liveness_probe {
            http_get {
              path = "/api"
              port = 8888
            }
            initial_delay_seconds = 60
            period_seconds        = 30
          }

          readiness_probe {
            http_get {
              path = "/api"
              port = 8888
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }
        }

        volume {
          name = "jupyter-home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim_v1.jupyter_storage.metadata[0].name
          }
        }

        volume {
          name = "examples"
          config_map {
            name = kubernetes_config_map_v1.jupyter_examples.metadata[0].name
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_config_map_v1.jupyter_config,
    kubernetes_config_map_v1.jupyter_examples,
    kubernetes_persistent_volume_claim_v1.jupyter_storage,
  ]
}

# Service
resource "kubernetes_service_v1" "jupyter" {
  metadata {
    name      = "jupyter"
    namespace = local.namespace
    labels    = local.jupyter_labels
  }

  spec {
    selector = {
      "app.kubernetes.io/name"      = "jupyter"
      "app.kubernetes.io/component" = "notebooks"
    }

    port {
      port        = 80
      target_port = 8888
      name        = "http"
    }
  }

  depends_on = [kubernetes_deployment_v1.jupyter]
}
