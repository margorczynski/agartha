resource "kubernetes_config_map_v1" "dagster_user_code" {
  metadata {
    name      = "dagster-user-code"
    namespace = local.namespace
    labels    = local.dagster_labels
  }

  data = {
    "definitions.py" = file("${path.module}/user_code/definitions.py")
  }

  depends_on = [
    kubernetes_namespace_v1.orchestration_namespace
  ]
}
