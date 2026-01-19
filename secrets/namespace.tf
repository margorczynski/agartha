resource "kubernetes_namespace_v1" "secrets_namespace" {
  metadata {
    name   = var.kubernetes_secrets_namespace
    labels = local.labels
  }
}
