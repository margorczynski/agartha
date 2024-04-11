resource "kubernetes_namespace" "storage_namespace" {
  metadata {
    name = var.kubernetes_storage_namespace
  }
}