resource "kubernetes_secret_v1" "minio_tenant_env" {
  metadata {
    name      = local.tenant_env_secret_name
    namespace = var.kubernetes_storage_namespace
  }

  data = {
    "config.env" = <<EOH
      export MINIO_ROOT_USER=${var.s3_access_key}
      export MINIO_ROOT_PASSWORD=${var.s3_secret_key}
      EOH
    
  }
}