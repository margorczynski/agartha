resource "helm_release" "trino" {
  namespace  = local.trino_namespace
  name       = "trino"
  repository = "https://trinodb.github.io/charts"
  chart      = "trino"

  # Issues with setting additionalCatalogs via 'set' so using template
  values = [
    "${templatefile("${path.module}/templates/trino_values.tftpl", {
        storage_s3_warehouse_location = "${var.storage_s3_warehouse_location}"
        storage_s3_endpoint           = "${var.storage_s3_endpoint}"
        storage_s3_access_key         = "${var.storage_s3_access_key}"
        storage_s3_secret_key         = "${var.storage_s3_secret_key}"
    })}"
  ]

  set = [
    {
      name  = "server.workers"
      value = var.trino_cluster_worker_num
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "trino-sa"
    }
  ]

  depends_on = [
    kubernetes_namespace_v1.processing_namespace_trino
  ]
}