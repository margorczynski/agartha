resource "kubernetes_namespace" "bi_namespace" {
  metadata {
    name = var.kubernetes_bi_namespace
  }
}