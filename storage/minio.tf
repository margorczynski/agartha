resource "helm_release" "minio_operator" {
  namespace  = var.kubernetes_storage_namespace
  name       = "minio-operator"
  repository = "https://operator.min.io"
  chart      = "operator"
  version    = "7.1.1"

  depends_on = [
    kubernetes_namespace_v1.storage_namespace
  ]
}

resource "helm_release" "minio_tenant" {
  namespace  = var.kubernetes_storage_namespace
  name       = "minio-tenant"
  repository = "https://operator.min.io"
  chart      = "tenant"
  version    = "7.1.1"

  set = [
    {
      name  = "tenant.name"
      value = local.tenant_name
    },
    {
      name  = "tenant.certificate.requestAutoCert"
      value = "false"
    },
    {
      name  = "tenant.configSecret.name"
      value = local.tenant_env_secret_name
    },
    {
      name  = "tenant.configSecret.existingSecret"
      value = "true"
    },
    #
    # Tenant pool resource settings
    #
    {
      name  = "tenant.pools[0].name"
      value = "pool-0"
    },
    {
      name  = "tenant.pools[0].servers"
      value = tostring(var.minio_tenant_servers_num)
    },
    {
      name  = "tenant.pools[0].volumesPerServer"
      value = tostring(var.minio_tenant_volumes_per_server_num)
    },
    {
      name  = "tenant.pools[0].size"
      value = "${tostring(var.minio_tenant_size_per_volume_gb)}Gi"
    },
    #
    # Bucket provisioning
    #
    {
      name  = "tenant.buckets[0].name"
      value = "${var.s3_warehouse_bucket_name}"
    },
    #
    # Prometheus metrics
    #
    {
      name  = "tenant.metrics.enabled"
      value = "true"
    },
    {
      name  = "tenant.metrics.port"
      value = "9000"
    },
    {
      name  = "tenant.prometheusOperator"
      value = "true"
    },
    #
    # Trust the ingress TLS certificate for OpenID Connect
    #
    {
      name  = "tenant.certificate.externalCaCertSecret[0].name"
      value = "minio-trusted-ca"
    }
  ]

  depends_on = [
    helm_release.minio_operator,
    kubernetes_secret_v1.minio_tenant_env
  ]
}