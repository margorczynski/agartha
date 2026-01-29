resource "kubernetes_secret_v1" "spark_s3_credentials" {
  metadata {
    name      = "spark-s3-credentials"
    namespace = local.spark_namespace
    labels = {
      app = "spark"
    }
  }

  data = {
    S3_ACCESS_KEY_ID     = var.storage_s3_access_key
    S3_SECRET_ACCESS_KEY = var.storage_s3_secret_key
  }

  depends_on = [
    kubernetes_namespace_v1.processing_namespace_spark
  ]
}

resource "kubernetes_secret_v1" "flink_s3_credentials" {
  metadata {
    name      = "flink-s3-credentials"
    namespace = local.flink_namespace
    labels = {
      app = "flink"
    }
  }

  data = {
    S3_ACCESS_KEY_ID     = var.storage_s3_access_key
    S3_SECRET_ACCESS_KEY = var.storage_s3_secret_key
  }

  depends_on = [
    kubernetes_namespace_v1.processing_namespace_flink
  ]
}

resource "kubernetes_secret_v1" "trino_s3_credentials" {
  metadata {
    name      = "trino-s3-credentials"
    namespace = local.trino_namespace
    labels = {
      app = "trino"
    }
  }

  data = {
    S3_ACCESS_KEY_ID     = var.storage_s3_access_key
    S3_SECRET_ACCESS_KEY = var.storage_s3_secret_key
  }

  depends_on = [
    kubernetes_namespace_v1.processing_namespace_trino
  ]
}

resource "kubernetes_secret_v1" "trino_auth_secrets" {
  metadata {
    name      = "trino-auth-secrets"
    namespace = local.trino_namespace
    labels = {
      app = "trino"
    }
  }

  data = {
    oauth-client-secret    = var.trino_oauth_client_secret
    internal-shared-secret = var.trino_internal_shared_secret
  }

  depends_on = [
    kubernetes_namespace_v1.processing_namespace_trino
  ]
}
