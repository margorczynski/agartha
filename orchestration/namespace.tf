resource "kubernetes_namespace_v1" "orchestration_namespace" {
  metadata {
    name   = local.namespace
    labels = local.dagster_labels
  }
}
