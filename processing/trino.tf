resource "helm_release" "trino" {
  namespace  = local.trino_namespace
  name       = "trino"
  repository = "https://trinodb.github.io/charts"
  chart      = "trino"
  version    = "1.41.0"

  timeout = 600 # 10 minutes for image pulls on slow connections

  # Issues with setting additionalCatalogs via 'set' so using template
  # NOTE: S3 credentials in additionalCatalogs and auth secrets in coordinator config
  # remain as template interpolation because Trino's catalog properties files and
  # server config don't support secretKeyRef or environment variable substitution.
  values = [
    templatefile("${path.module}/templates/trino_values.tftpl", {
      storage_s3_warehouse_location         = var.storage_s3_warehouse_location
      storage_s3_endpoint                   = var.storage_s3_endpoint
      storage_s3_access_key                 = var.storage_s3_access_key
      storage_s3_secret_key                 = var.storage_s3_secret_key
      keycloak_issuer_url                   = var.keycloak_issuer_url
      keycloak_auth_url                     = var.keycloak_auth_url
      keycloak_token_url                    = var.keycloak_token_url
      keycloak_jwks_url                     = var.keycloak_jwks_url
      keycloak_userinfo_url                 = var.keycloak_userinfo_url
      trino_oauth_client_id                 = var.trino_oauth_client_id
      trino_oauth_client_secret             = var.trino_oauth_client_secret
      trino_internal_shared_secret          = var.trino_internal_shared_secret
      coordinator_resources                 = var.trino_coordinator_resources
      worker_resources                      = var.trino_worker_resources
      coordinator_graceful_shutdown_seconds = var.trino_coordinator_graceful_shutdown_seconds
      worker_graceful_shutdown_seconds      = var.trino_worker_graceful_shutdown_seconds
    })
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
    kubernetes_namespace_v1.processing_namespace_trino,
    kubernetes_secret_v1.trino_s3_credentials,
    kubernetes_secret_v1.trino_auth_secrets
  ]
}