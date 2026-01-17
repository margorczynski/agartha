# Secret for S3 credentials used by Nessie catalog
resource "kubernetes_secret_v1" "nessie_s3_credentials" {
  metadata {
    name      = "nessie-s3-credentials"
    namespace = var.kubernetes_catalog_namespace
  }

  data = {
    "aws-access-key" = var.storage_s3_access_key
    "aws-secret-key" = var.storage_s3_secret_key
  }

  depends_on = [
    kubernetes_namespace_v1.catalog_namespace
  ]
}

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
    },
    # Iceberg REST catalog configuration
    {
      name  = "catalog.enabled"
      value = "true"
    },
    # S3 storage configuration
    {
      name  = "catalog.storage.s3.defaultOptions.endpoint"
      value = var.storage_s3_endpoint
    },
    {
      name  = "catalog.storage.s3.defaultOptions.pathStyleAccess"
      value = "true"
    },
    {
      name  = "catalog.storage.s3.defaultOptions.region"
      value = "us-east-1"
    },
    {
      name  = "catalog.storage.s3.defaultOptions.authType"
      value = "STATIC"
    },
    {
      name  = "catalog.storage.s3.defaultOptions.accessKeySecret.name"
      value = kubernetes_secret_v1.nessie_s3_credentials.metadata[0].name
    },
    {
      name  = "catalog.storage.s3.defaultOptions.accessKeySecret.awsAccessKeyId"
      value = "aws-access-key"
    },
    {
      name  = "catalog.storage.s3.defaultOptions.accessKeySecret.awsSecretAccessKey"
      value = "aws-secret-key"
    },
    # Warehouse configuration
    {
      name  = "catalog.iceberg.defaultWarehouse"
      value = "warehouse"
    },
    {
      name  = "catalog.iceberg.warehouses[0].name"
      value = "warehouse"
    },
    {
      name  = "catalog.iceberg.warehouses[0].location"
      value = "s3://${var.storage_s3_warehouse_bucket}/"
    }
  ]

  depends_on = [
    kubernetes_namespace_v1.catalog_namespace,
    kubernetes_secret_v1.nessie_s3_credentials
  ]
}