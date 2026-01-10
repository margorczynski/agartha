resource "kubernetes_namespace_v1" "processing_namespace_spark" {
  metadata {
    name = local.spark_namespace
  }
}

resource "kubernetes_namespace_v1" "processing_namespace_flink" {
  metadata {
    name = local.flink_namespace
  }
}

resource "kubernetes_namespace_v1" "processing_namespace_trino" {
  metadata {
    name = local.trino_namespace
  }
}