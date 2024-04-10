resource "kubernetes_namespace" "agartha_storage_namespace" {
  metadata {
    name = var.kubernetes_storage_namespace
  }
}