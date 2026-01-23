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

  storage_s3_endpoint         = "http://minio.agartha-storage.svc.cluster.local"
  storage_s3_access_key       = var.storage_s3_access_key
  storage_s3_secret_key       = var.storage_s3_secret_key
  storage_s3_warehouse_bucket = var.storage_s3_warehouse_bucket_name

  depends_on = [
    module.agartha_storage
  ]
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

  # Keycloak OAuth integration
  grafana_oauth_client_id     = module.agartha_identity.keycloak_grafana_client_id
  grafana_oauth_client_secret = module.agartha_identity.keycloak_grafana_client_secret
  keycloak_auth_url           = module.agartha_identity.keycloak_auth_url
  keycloak_token_url          = module.agartha_identity.keycloak_token_url
  keycloak_userinfo_url       = module.agartha_identity.keycloak_userinfo_url

  depends_on = [
    module.agartha_identity
  ]
}

module "agartha_identity" {
  source = "./identity"

  kubernetes_identity_namespace = "agartha-identity"
  kubernetes_ingress_base_host  = local.agartha_host

  keycloak_admin_password           = var.identity_keycloak_admin_password
  keycloak_postgres_password        = var.identity_keycloak_postgres_password
  keycloak_postgres_storage_size_gb = 10
  keycloak_replicas                 = 1

  grafana_oauth_client_secret  = var.identity_grafana_oauth_client_secret
  superset_oauth_client_secret = var.identity_superset_oauth_client_secret
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
    module.agartha_monitoring,
    module.agartha_identity
  ]
}

module "business_intelligence" {
  source = "./business_intelligence"

  kubernetes_bi_namespace      = "agartha-bi"
  kubernetes_ingress_base_host = local.agartha_host

  superset_node_replica_num   = 1
  superset_worker_replica_num = 1

  # Keycloak OAuth integration
  superset_oauth_client_id     = module.agartha_identity.keycloak_superset_client_id
  superset_oauth_client_secret = module.agartha_identity.keycloak_superset_client_secret
  keycloak_auth_url            = module.agartha_identity.keycloak_auth_url
  keycloak_token_url           = module.agartha_identity.keycloak_token_url
  keycloak_issuer_url          = module.agartha_identity.keycloak_issuer_url
  keycloak_jwks_url            = module.agartha_identity.keycloak_jwks_url
  keycloak_api_base_url        = module.agartha_identity.keycloak_api_base_url

  depends_on = [
    module.agartha_processing,
    module.agartha_identity
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

  nessie_uri = "http://nessie.agartha-catalog.svc.cluster.local:19120/iceberg"
  trino_host = "trino.agartha-processing-trino.svc.cluster.local"
  trino_port = 8080

  jupyter_storage_size_gb = 5

  depends_on = [
    module.agartha_storage,
    module.agartha_catalog,
    module.agartha_processing
  ]
}