resource "helm_release" "nessie" {
  namespace  = var.kubernetes_catalog_namespace
  name       = "nessie"
  repository = "https://charts.projectnessie.org"
  chart      = "nessie"

set {
    name =  "serviceAccount.name"
    value = "nessie-sa"
  }

  set {
    name =  "versionStoreType"
    value = "ROCKSDB"
  }

  set {
    name =  "rocksdb.storageClassName"
    value = "standard"
  }

  set {
    name =  "rocksdb.storageSize"
    value = "2Gi"
  }
}