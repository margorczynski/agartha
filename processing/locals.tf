locals {
  spark_namespace = "${var.kubernetes_processing_namespace_base}-spark"
  flink_namespace = "${var.kubernetes_processing_namespace_base}-flink"
  trino_namespace = "${var.kubernetes_processing_namespace_base}-trino"
}
