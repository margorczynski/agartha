resource "kubernetes_config_map_v1" "spark_storage_config" {
  metadata {
    name      = "spark-storage-config"
    namespace = local.spark_namespace
    labels = {
      app = "spark"
    }
  }

  data = {
    NESSIE_URI           = "http://nessie.agartha-catalog.svc.cluster.local:19120/api/v2"
    NESSIE_REF           = "main"
    S3_ENDPOINT          = "http://minio.agartha-storage.svc.cluster.local:9000"
    S3_WAREHOUSE         = "s3a://agartha-warehouse/"
    S3_ACCESS_KEY_ID     = var.storage_s3_access_key
    S3_SECRET_ACCESS_KEY = var.storage_s3_secret_key
    S3_REGION            = "us-east-1"
    S3_PATH_STYLE_ACCESS = "true"
    S3_SSL_ENABLED       = "false"
  }

  depends_on = [
    kubernetes_namespace_v1.processing_namespace_spark
  ]
}

resource "kubernetes_config_map_v1" "flink_storage_config" {
  metadata {
    name      = "flink-storage-config"
    namespace = local.flink_namespace
    labels = {
      app = "flink"
    }
  }

  data = {
    NESSIE_URI           = "http://nessie.agartha-catalog.svc.cluster.local:19120/api/v2"
    NESSIE_REF           = "main"
    S3_ENDPOINT          = "http://minio.agartha-storage.svc.cluster.local:9000"
    S3_WAREHOUSE         = "s3a://agartha-warehouse/"
    S3_ACCESS_KEY_ID     = var.storage_s3_access_key
    S3_SECRET_ACCESS_KEY = var.storage_s3_secret_key
    S3_REGION            = "us-east-1"
    S3_PATH_STYLE_ACCESS = "true"
  }

  depends_on = [
    kubernetes_namespace_v1.processing_namespace_flink
  ]
}

resource "kubernetes_config_map_v1" "trino_storage_config" {
  metadata {
    name      = "trino-storage-config"
    namespace = local.trino_namespace
    labels = {
      app = "trino"
    }
  }

  data = {
    NESSIE_URI           = "http://nessie.agartha-catalog.svc.cluster.local:19120/api/v2"
    S3_ENDPOINT          = var.storage_s3_endpoint
    S3_WAREHOUSE         = var.storage_s3_warehouse_location
    S3_ACCESS_KEY_ID     = var.storage_s3_access_key
    S3_SECRET_ACCESS_KEY = var.storage_s3_secret_key
    S3_REGION            = "us-east-1"
    S3_PATH_STYLE_ACCESS = "true"
  }

  depends_on = [
    kubernetes_namespace_v1.processing_namespace_trino
  ]
}
