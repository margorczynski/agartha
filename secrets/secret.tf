resource "kubernetes_secret_v1" "openbao_root_token" {
  metadata {
    name      = local.openbao_root_token_secret_name
    namespace = var.kubernetes_secrets_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "Helm"
      "app.kubernetes.io/component"  = "secrets"
    }
  }

  data = {
    "root-token" = var.openbao_root_token
  }

  depends_on = [
    kubernetes_namespace_v1.secrets_namespace
  ]
}
