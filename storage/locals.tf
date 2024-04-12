locals {
  tenant_name           = "minio-tenant"
  operator_console_path = "${var.kubernetes_ingress_base_path}/operator-console"
  tenant_console_path   = "${var.kubernetes_ingress_base_path}/tenant-console"
  tenant_env_secret_name = "minio-tenant-env"
}