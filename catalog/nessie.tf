resource "helm_release" "nessie" {
  namespace  = var.kubernetes_catalog_namespace
  name       = "nessie"
  repository = "https://charts.projectnessie.org"
  chart      = "nessie"

  set = [
    {
      name  = "serviceAccount.name"
      value = "nessie-sa"
    },
    {
      name  = "versionStoreType"
      value = "ROCKSDB"
    },
    {
      name  = "rocksdb.storageClassName"
      value = "standard"
    },
    {
      name  = "rocksdb.storageSize"
      value = "2Gi"
    }
  ]
}