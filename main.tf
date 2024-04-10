module "agartha_storage" {
  source = "./storage"

  kubernetes_config_path              = "${var.kubernetes_config_path}"
  kubernetes_storage_namespace        = "agartha-storage"
  kubernetes_ingress_base_path        = "/agartha/storage"
  minio_tenant_servers_num            = 1
  minio_tenant_volumes_per_server_num = 4
  minio_tenant_size_per_volume_gb     = 4
}