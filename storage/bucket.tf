resource "null_resource" "create_warehouse_bucket" {
  depends_on = [helm_release.minio_tenant]

  provisioner "local-exec" {
    command = "kubectl exec -n ${var.kubernetes_storage_namespace} ${local.tenant_name}-pool-0-0 -c minio -- sh -c 'mc alias set local http://localhost:9000 ${var.s3_access_key} ${var.s3_secret_key} && mc mb --ignore-existing local/${var.s3_warehouse_bucket_name}'"
  }
}
