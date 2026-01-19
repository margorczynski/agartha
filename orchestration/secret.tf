resource "kubernetes_secret_v1" "dagster_postgres_credentials" {
  metadata {
    name      = local.dagster_postgres_secret_name
    namespace = local.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
      "app.kubernetes.io/component"  = "orchestration"
    }
  }

  data = {
    "password" = var.dagster_postgres_password
    "postgres-password" = var.dagster_postgres_password
  }

  depends_on = [
    kubernetes_namespace_v1.orchestration_namespace
  ]
}

resource "kubernetes_secret_v1" "dagster_s3_credentials" {
  metadata {
    name      = "dagster-s3-credentials"
    namespace = local.namespace
    labels = {
      "app.kubernetes.io/name"       = "dagster"
      "app.kubernetes.io/component"  = "orchestration"
      "app.kubernetes.io/part-of"    = "agartha"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "S3_ACCESS_KEY_ID"     = var.storage_s3_access_key
    "S3_SECRET_ACCESS_KEY" = var.storage_s3_secret_key
  }

  depends_on = [
    kubernetes_namespace_v1.orchestration_namespace
  ]
}
