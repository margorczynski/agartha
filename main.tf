module "agartha_storage" {
  source = "./storage"

  kubernetes_storage_namespace = "agartha-storage"
  kubernetes_ingress_base_host = local.agartha_host

  s3_warehouse_bucket_name = var.storage_s3_warehouse_bucket_name
  s3_access_key            = var.storage_s3_access_key
  s3_secret_key            = var.storage_s3_secret_key

  minio_tenant_servers_num            = 1
  minio_tenant_volumes_per_server_num = 4
  minio_tenant_size_per_volume_gb     = 4
}

module "agartha_catalog" {
  source = "./catalog"

  kubernetes_catalog_namespace = "agartha-catalog"
  kubernetes_ingress_base_host = local.agartha_host
}

module "agartha_processing" {
  source = "./processing"

  kubernetes_processing_namespace_base = "agartha-processing"
  kubernetes_ingress_base_host         = local.agartha_host

  storage_s3_warehouse_location = "s3a://${var.storage_s3_warehouse_bucket_name}/"
  storage_s3_endpoint           = "http://minio.agartha-storage.svc.cluster.local"
  storage_s3_access_key         = var.storage_s3_access_key
  storage_s3_secret_key         = var.storage_s3_secret_key

  trino_cluster_worker_num = 2
}

module "business_intelligence" {
  source = "./business_intelligence"

  kubernetes_bi_namespace      = "agartha-bi"
  kubernetes_ingress_base_host = local.agartha_host

  superset_node_replica_num   = 1
  superset_worker_replica_num = 1
}

module "agartha_monitoring" {
  source = "./monitoring"

  kubernetes_monitoring_namespace = "agartha-monitoring"
  kubernetes_ingress_base_host    = local.agartha_host

  grafana_admin_password     = var.monitoring_grafana_admin_password
  prometheus_retention_days  = 15
  prometheus_storage_size_gb = 10
  grafana_storage_size_gb    = 2

  minio_namespace  = "agartha-storage"
  nessie_namespace = "agartha-catalog"
  trino_namespace  = "agartha-processing-trino"
  spark_namespace  = "agartha-processing-spark"
  flink_namespace  = "agartha-processing-flink"

  loki_storage_size_gb = 10
}