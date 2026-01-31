resource "random_bytes" "minio_encryption_key" {
  length = 32

  lifecycle {
    precondition {
      condition     = var.minio_tenant_servers_num == 1 || (var.minio_tenant_servers_num * var.minio_tenant_volumes_per_server_num) >= 4
      error_message = "Distributed mode (servers > 1) requires at least 4 total drives (servers * volumes_per_server >= 4) for erasure coding."
    }
  }
}

locals {
  encryption_key_b64 = random_bytes.minio_encryption_key.base64
}
