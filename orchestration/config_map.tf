resource "kubernetes_config_map_v1" "dagster_storage_config" {
  metadata {
    name      = "dagster-storage-config"
    namespace = local.namespace
    labels    = local.dagster_labels
  }

  data = {
    NESSIE_URI           = local.nessie_catalog_uri
    NESSIE_REF           = "main"
    S3_ENDPOINT          = local.s3_endpoint
    S3_WAREHOUSE         = local.warehouse_location
    S3_ACCESS_KEY_ID     = var.storage_s3_access_key
    S3_SECRET_ACCESS_KEY = var.storage_s3_secret_key
    S3_REGION            = "us-east-1"
    S3_PATH_STYLE_ACCESS = "true"
    S3_SSL_ENABLED       = "false"
  }

  depends_on = [
    kubernetes_namespace_v1.orchestration_namespace
  ]
}

resource "kubernetes_config_map_v1" "dagster_spark_config" {
  metadata {
    name      = "dagster-spark-config"
    namespace = local.namespace
    labels    = local.dagster_labels
  }

  data = {
    SPARK_NAMESPACE       = var.spark_namespace
    SPARK_SERVICE_ACCOUNT = "spark-sa"
    SPARK_IMAGE           = "openlake/spark-py:3.3.2"
  }

  depends_on = [
    kubernetes_namespace_v1.orchestration_namespace
  ]
}

resource "kubernetes_config_map_v1" "dagster_flink_config" {
  metadata {
    name      = "dagster-flink-config"
    namespace = local.namespace
    labels    = local.dagster_labels
  }

  data = {
    FLINK_NAMESPACE = var.flink_namespace
    FLINK_IMAGE     = "apache/flink:1.18.1-scala_2.12-java11"
  }

  depends_on = [
    kubernetes_namespace_v1.orchestration_namespace
  ]
}
