module "agartha_storage" {
  source = "./storage"

  kubernetes_storage_namespace = "agartha-storage"
  kubernetes_ingress_base_host = local.agartha_host

  s3_warehouse_bucket_name = var.storage_s3_warehouse_bucket_name
  s3_raw_bucket_name       = var.storage_s3_raw_bucket_name
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

module "agartha_processing" {
  source = "./processing"

  kubernetes_processing_namespace_base = "agartha-processing"
  kubernetes_ingress_base_host         = local.agartha_host

  storage_s3_warehouse_location = "s3a://${var.storage_s3_warehouse_bucket_name}/"
  storage_s3_endpoint           = "http://minio.agartha-storage.svc.cluster.local"
  storage_s3_access_key         = var.storage_s3_access_key
  storage_s3_secret_key         = var.storage_s3_secret_key

  trino_cluster_worker_num = 2

  depends_on = [
    module.agartha_monitoring
  ]
}

module "business_intelligence" {
  source = "./business_intelligence"

  kubernetes_bi_namespace      = "agartha-bi"
  kubernetes_ingress_base_host = local.agartha_host

  superset_node_replica_num   = 1
  superset_worker_replica_num = 1

  depends_on = [
    module.agartha_processing
  ]
}

module "agartha_orchestration" {
  source = "./orchestration"

  kubernetes_orchestration_namespace = "agartha-orchestration"
  kubernetes_ingress_base_host       = local.agartha_host

  storage_s3_warehouse_location = "s3a://${var.storage_s3_warehouse_bucket_name}/"
  storage_s3_endpoint           = "http://minio.agartha-storage.svc.cluster.local"
  storage_s3_access_key         = var.storage_s3_access_key
  storage_s3_secret_key         = var.storage_s3_secret_key

  dagster_webserver_replica_num               = 1
  dagster_postgres_password                   = var.orchestration_dagster_postgres_password
  dagster_run_coordinator_max_concurrent_runs = 10

  spark_namespace = "agartha-processing-spark"
  flink_namespace = "agartha-processing-flink"

  depends_on = [
    module.agartha_processing
  ]
}

module "agartha_notebooks" {
  source = "./notebooks"

  kubernetes_notebooks_namespace = "agartha-notebooks"
  kubernetes_ingress_base_host   = local.agartha_host

  storage_s3_endpoint   = "http://minio.agartha-storage.svc.cluster.local:9000"
  storage_s3_access_key = var.storage_s3_access_key
  storage_s3_secret_key = var.storage_s3_secret_key
  storage_s3_warehouse  = "s3://${var.storage_s3_warehouse_bucket_name}"
  storage_s3_raw_bucket = var.storage_s3_raw_bucket_name

  nessie_uri = "http://nessie.agartha-catalog.svc.cluster.local:19120/api/v2"
  trino_host = "trino.agartha-processing-trino.svc.cluster.local"
  trino_port = 8080

  jupyter_storage_size_gb = 5

  depends_on = [
    module.agartha_storage,
    module.agartha_catalog,
    module.agartha_processing
  ]
}