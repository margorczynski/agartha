module "agartha_storage" {
  source = "./storage"

  kubernetes_storage_namespace = "agartha-storage"
  kubernetes_ingress_host      = var.ingress_host
  kubernetes_ingress_base_path = "${var.ingress_base_path}/storage"

  s3_warehouse_bucket_name = "agartha"
  s3_access_key            = "agartha"
  s3_secret_key            = "agartha"

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

  storage_s3_warehouse_location = "s3a://agartha-warehouse/"
  storage_s3_endpoint           = "http://minio.agartha-storage.svc.cluster.local"
  storage_s3_access_key         = "agartha"
  storage_s3_secret_key         = "agartha"

  trino_cluster_worker_num      = 2
}