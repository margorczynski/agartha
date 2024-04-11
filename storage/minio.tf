resource "helm_release" "minio_operator" {
  namespace  = var.kubernetes_storage_namespace
  name       = "minio-operator"
  repository = "https://operator.min.io"
  chart      = "operator"

  set {
    name =  "console.env[0].name"
    value = "OPERATOR_SUBPATH"
  }

  set {
    name =  "console.env[0].value"
    value = "${local.operator_console_path}/"
  }
}

resource "helm_release" "minio_tenant" {
  namespace  = var.kubernetes_storage_namespace
  name       = "minio-tenant"
  repository = "https://operator.min.io"
  chart      = "tenant"

  set {
    name =  "tenant.name"
    value = local.tenant_name
  }

  set {
    name =  "tenant.certificate.requestAutoCert"
    value = "false"
  }

  set {
    name =  "tenant.configuration.name"
    value = local.tenant_env_secret_name
  }

  #
  # Tenant pool resource settings
  #
  set {
    name =  "tenant.pools[0].servers"
    value = tostring(var.minio_tenant_servers_num)
  }

  set {
    name =  "tenant.pools[0].volumesPerServer"
    value = tostring(var.minio_tenant_volumes_per_server_num)
  }

  set {
    name =  "tenant.pools[0].size"
    value = "${tostring(var.minio_tenant_size_per_volume_gb)}Gi"
  }

  #
  # Bucket provisioning
  #
  set {
    name =  "tenant.buckets[0].name"
    value = "${var.s3_warehouse_bucket_name}"
  }

  depends_on = [ helm_release.minio_operator ]
}