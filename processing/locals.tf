locals {
  spark_namespace = "${var.kubernetes_processing_namespace_base}-spark"
  flink_namespace = "${var.kubernetes_processing_namespace_base}-flink"
  trino_namespace = "${var.kubernetes_processing_namespace_base}-trino"

  nessie_catalog_uri = "http://nessie.agartha-catalog.svc.cluster.local:19120/api/v2"
  s3_endpoint        = var.storage_s3_endpoint
  warehouse_location  = var.storage_s3_warehouse_location
}