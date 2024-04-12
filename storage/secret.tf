resource "kubernetes_secret" "minio_tenant_env" {
  metadata {
    name = local.tenant_env_secret_name
    namespace = var.kubernetes_storage_namespace
  }

  data = {
    "config.env" = <<EOH
      export MINIO_ROOT_USER=agartha
      export MINIO_ROOT_PASSWORD=mypassword
      EOH
    
  }
}