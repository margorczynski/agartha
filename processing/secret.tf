resource "kubernetes_secret_v1" "spark_s3_credentials" {
  metadata {
    name      = local.spark_s3_secret_name
    namespace = local.spark_namespace
    labels = {
      "app.kubernetes.io/name"       = "spark"
      "app.kubernetes.io/component"  = "processing"
      "app.kubernetes.io/part-of"    = "agartha"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "S3_ACCESS_KEY_ID"     = var.storage_s3_access_key
    "S3_SECRET_ACCESS_KEY" = var.storage_s3_secret_key
  }

  depends_on = [
    kubernetes_namespace_v1.processing_namespace_spark
  ]
}

resource "kubernetes_secret_v1" "flink_s3_credentials" {
  metadata {
    name      = local.flink_s3_secret_name
    namespace = local.flink_namespace
    labels = {
      "app.kubernetes.io/name"       = "flink"
      "app.kubernetes.io/component"  = "processing"
      "app.kubernetes.io/part-of"    = "agartha"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "S3_ACCESS_KEY_ID"     = var.storage_s3_access_key
    "S3_SECRET_ACCESS_KEY" = var.storage_s3_secret_key
  }

  depends_on = [
    kubernetes_namespace_v1.processing_namespace_flink
  ]
}

resource "kubernetes_secret_v1" "trino_s3_credentials" {
  metadata {
    name      = local.trino_s3_secret_name
    namespace = local.trino_namespace
    labels = {
      "app.kubernetes.io/name"       = "trino"
      "app.kubernetes.io/component"  = "processing"
      "app.kubernetes.io/part-of"    = "agartha"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "S3_ACCESS_KEY_ID"     = var.storage_s3_access_key
    "S3_SECRET_ACCESS_KEY" = var.storage_s3_secret_key
  }

  depends_on = [
    kubernetes_namespace_v1.processing_namespace_trino
  ]
}
