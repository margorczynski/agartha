resource "kubernetes_config_map_v1" "minio_policies" {
  metadata {
    name      = "minio-policies"
    namespace = var.kubernetes_storage_namespace
  }

  data = {
    "minio-admins.json" = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["admin:*"]
          Resource = ["arn:aws:s3:::*"]
        },
        {
          Effect   = "Allow"
          Action   = ["s3:*"]
          Resource = ["arn:aws:s3:::*"]
        }
      ]
    })
    "minio-readwrite.json" = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["s3:*"]
          Resource = ["arn:aws:s3:::*"]
        }
      ]
    })
    "minio-readonly.json" = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = ["arn:aws:s3:::*"]
        }
      ]
    })
  }

  depends_on = [kubernetes_namespace_v1.storage_namespace]
}

resource "kubernetes_job_v1" "minio_policy_setup" {
  metadata {
    name      = "minio-policy-setup"
    namespace = var.kubernetes_storage_namespace
  }

  spec {
    template {
      metadata {
        labels = {
          app = "minio-policy-setup"
        }
      }
      spec {
        restart_policy = "OnFailure"
        container {
          name    = "mc"
          image   = "minio/mc:latest"
          command = ["/bin/sh", "-c"]
          args = [<<-EOT
            set -e
            # Wait for MinIO to be ready
            until mc alias set myminio http://${local.tenant_name}-hl.${var.kubernetes_storage_namespace}.svc.cluster.local:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" 2>/dev/null; do
              echo "Waiting for MinIO..."
              sleep 5
            done
            # Create policies
            mc admin policy create myminio minio-admins /policies/minio-admins.json || true
            mc admin policy create myminio minio-readwrite /policies/minio-readwrite.json || true
            mc admin policy create myminio minio-readonly /policies/minio-readonly.json || true
            echo "Policies created successfully"
          EOT
          ]
          env {
            name  = "MINIO_ROOT_USER"
            value = var.s3_access_key
          }
          env {
            name  = "MINIO_ROOT_PASSWORD"
            value = var.s3_secret_key
          }
          volume_mount {
            name       = "policies"
            mount_path = "/policies"
          }
        }
        volume {
          name = "policies"
          config_map {
            name = kubernetes_config_map_v1.minio_policies.metadata[0].name
          }
        }
      }
    }
  }

  wait_for_completion = true
  timeouts {
    create = "5m"
  }

  depends_on = [
    helm_release.minio_tenant,
    kubernetes_config_map_v1.minio_policies
  ]
}
