resource "helm_release" "minio_operator" {
  namespace  = var.kubernetes_storage_namespace
  name       = "agartha-minio-operator"
  repository = "https://operator.min.io"
  chart      = "operator"

  values = [
    file("${path.module}/files/minio-operator-values.yaml")
  ]

  set {
    name =  "console.env[0].name"
    value = "OPERATOR_SUBPATH"
  }

    set {
    name =  "console.env[0].value"
    value = local.operator_console_path
  }
}

resource "helm_release" "minio_tenant" {
  namespace  = var.kubernetes_storage_namespace
  name       = "agartha-minio-tenant"
  repository = "https://operator.min.io"
  chart      = "tenant"

  values = [
    file("${path.module}/files/minio-tenant-values.yaml")
  ]

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

  depends_on = [ helm_release.minio_operator ]
}