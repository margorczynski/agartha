locals {
  namespace = var.kubernetes_orchestration_namespace

  nessie_catalog_uri = "http://nessie.agartha-catalog.svc.cluster.local:19120/api/v2"
  s3_endpoint        = var.storage_s3_endpoint
  warehouse_location = var.storage_s3_warehouse_location

  dagster_labels = {
    "app.kubernetes.io/name"       = "dagster"
    "app.kubernetes.io/component"  = "orchestration"
    "app.kubernetes.io/part-of"    = "agartha"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}
