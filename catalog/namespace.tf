resource "kubernetes_namespace" "catalog_namespace" {
  metadata {
    name = var.kubernetes_catalog_namespace
  }
}