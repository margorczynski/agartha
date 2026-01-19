resource "helm_release" "openbao" {
  namespace  = var.kubernetes_secrets_namespace
  name       = "openbao"
  repository = "https://openbao.github.io/openbao-helm"
  chart      = "openbao"
  version    = "0.23.3"

  values = [
    templatefile("${path.module}/templates/openbao_values.tftpl", {
      dev_mode_enabled            = var.openbao_dev_mode
      openbao_root_token          = var.openbao_root_token
      ui_enabled                  = var.openbao_ui_enabled
      data_storage_size_gb        = var.openbao_data_storage_size_gb
      namespace                   = var.kubernetes_secrets_namespace
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.secrets_namespace
  ]
}
