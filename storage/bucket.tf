resource "null_resource" "create_buckets" {
  depends_on = [helm_release.minio_tenant]

  triggers = {
    namespace_uid    = kubernetes_namespace_v1.storage_namespace.id
    warehouse_bucket = var.s3_warehouse_bucket_name
    raw_bucket       = var.s3_raw_bucket_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for MinIO tenant to be ready..."

      # Wait for tenant pods to be created
      timeout=300
      elapsed=0
      while [ $elapsed -lt $timeout ]; do
        POD_NAME=$(kubectl get pods -n ${var.kubernetes_storage_namespace} -l v1.min.io/tenant=${local.tenant_name} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [ -n "$POD_NAME" ]; then
          echo "Found tenant pod: $POD_NAME, checking readiness..."
          break
        fi
        echo "Waiting for tenant pods to be created... ($elapsed/$timeout seconds)"
        sleep 5
        elapsed=$((elapsed + 5))
      done

      if [ -z "$POD_NAME" ]; then
        echo "ERROR: Timeout waiting for tenant pods"
        exit 1
      fi

      # Wait for the pod to be ready
      kubectl wait --for=condition=ready pod -n ${var.kubernetes_storage_namespace} $POD_NAME --timeout=300s
      echo "MinIO pod $POD_NAME is ready"

      # Give MinIO time to fully initialize
      sleep 10

      # Create buckets with retry logic
      for i in 1 2 3; do
        if kubectl exec -n ${var.kubernetes_storage_namespace} $POD_NAME -c minio -- sh -c 'mc alias set local http://localhost:9000 ${var.s3_access_key} ${var.s3_secret_key} && mc mb --ignore-existing local/${var.s3_warehouse_bucket_name} && mc mb --ignore-existing local/${var.s3_raw_bucket_name}'; then
          echo "Buckets created successfully"
          exit 0
        fi
        echo "Bucket creation attempt $i failed, retrying..."
        sleep 5
      done
      echo "Failed to create buckets after 3 attempts"
      exit 1
    EOT
  }
}