resource "kubernetes_secret_v1" "minio_trusted_ca" {
  metadata {
    name      = "minio-trusted-ca"
    namespace = var.kubernetes_storage_namespace
  }

  data = {
    "public.crt" = var.tls_certificate
  }

  depends_on = [
    kubernetes_namespace_v1.storage_namespace
  ]
}

resource "kubernetes_secret_v1" "minio_tenant_env" {
  metadata {
    name      = local.tenant_env_secret_name
    namespace = var.kubernetes_storage_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
    }
    annotations = {
      "meta.helm.sh/release-name"      = "minio-tenant"
      "meta.helm.sh/release-namespace" = var.kubernetes_storage_namespace
    }
  }

  data = {
    "config.env" = <<-EOH
export MINIO_ROOT_USER="${var.s3_access_key}"
export MINIO_ROOT_PASSWORD="${var.s3_secret_key}"
export MINIO_BROWSER=on
export MINIO_IDENTITY_OPENID_CONFIG_URL="${var.keycloak_openid_config_url}"
export MINIO_IDENTITY_OPENID_CLIENT_ID="${var.minio_oauth_client_id}"
export MINIO_IDENTITY_OPENID_CLIENT_SECRET="${var.minio_oauth_client_secret}"
export MINIO_IDENTITY_OPENID_SCOPES="openid,profile,email,groups"
export MINIO_IDENTITY_OPENID_CLAIM_NAME="groups"
export MINIO_IDENTITY_OPENID_DISPLAY_NAME="Keycloak"
export MINIO_IDENTITY_OPENID_REDIRECT_URI_DYNAMIC="on"
EOH
  }

  depends_on = [
    kubernetes_namespace_v1.storage_namespace
  ]
}