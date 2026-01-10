resource "kubernetes_namespace_v1" "storage_namespace" {
  metadata {
    name = var.kubernetes_storage_namespace
  }
}