resource "helm_release" "dagster" {
  namespace  = local.namespace
  name       = "dagster"
  repository = "https://dagster-io.github.io/helm"
  chart      = "dagster"
  version    = "1.12.11"

  values = [
    templatefile("${path.module}/templates/dagster_values.tftpl", {
      namespace                  = local.namespace
      webserver_replica_num      = var.dagster_webserver_replica_num
      max_concurrent_runs        = var.dagster_run_coordinator_max_concurrent_runs
      service_account_name       = kubernetes_service_account_v1.dagster_sa.metadata[0].name
      storage_config_map_name    = kubernetes_config_map_v1.dagster_storage_config.metadata[0].name
      s3_credentials_secret_name = kubernetes_secret_v1.dagster_s3_credentials.metadata[0].name
      spark_config_map_name      = kubernetes_config_map_v1.dagster_spark_config.metadata[0].name
      flink_config_map_name      = kubernetes_config_map_v1.dagster_flink_config.metadata[0].name
      user_code_config_map_name  = kubernetes_config_map_v1.dagster_user_code.metadata[0].name
      nessie_uri                 = local.nessie_catalog_uri
      s3_endpoint                = local.s3_endpoint
      s3_warehouse               = local.warehouse_location
      postgres_existing_secret   = kubernetes_secret_v1.dagster_postgres_password.metadata[0].name
      postgres_storage_size_gb   = var.dagster_postgres_storage_size_gb
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.orchestration_namespace,
    kubernetes_service_account_v1.dagster_sa,
    kubernetes_config_map_v1.dagster_storage_config,
    kubernetes_config_map_v1.dagster_user_code,
    kubernetes_role_binding_v1.dagster_job_runner_binding,
    kubernetes_secret_v1.dagster_s3_credentials,
    kubernetes_secret_v1.dagster_postgres_password
  ]
}
