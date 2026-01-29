resource "kubernetes_secret_v1" "dagster_s3_credentials" {
  metadata {
    name      = "dagster-s3-credentials"
    namespace = local.namespace
    labels    = local.dagster_labels
  }

  data = {
    S3_ACCESS_KEY_ID     = var.storage_s3_access_key
    S3_SECRET_ACCESS_KEY = var.storage_s3_secret_key
  }

  depends_on = [
    kubernetes_namespace_v1.orchestration_namespace
  ]
}

resource "kubernetes_secret_v1" "dagster_postgres_password" {
  metadata {
    name      = "dagster-postgres-password"
    namespace = local.namespace
    labels    = local.dagster_labels
  }

  data = {
    password          = var.dagster_postgres_password
    postgres-password = var.dagster_postgres_password
  }

  depends_on = [
    kubernetes_namespace_v1.orchestration_namespace
  ]
}

resource "kubernetes_secret_v1" "dagster_oauth2_proxy_secret" {
  metadata {
    name      = "dagster-oauth2-proxy-secret"
    namespace = local.namespace
  }

  data = {
    client-id     = var.dagster_oauth_client_id
    client-secret = var.dagster_oauth_client_secret
    cookie-secret = var.dagster_oauth_cookie_secret
  }

  depends_on = [
    kubernetes_namespace_v1.orchestration_namespace
  ]
}
