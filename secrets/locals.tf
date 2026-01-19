locals {
  openbao_root_token_secret_name = "openbao-root-token"

  labels = {
    "app.kubernetes.io/name"       = "openbao"
    "app.kubernetes.io/component"  = "secrets"
    "app.kubernetes.io/part-of"    = "agartha"
    "app.kubernetes.io/managed-by" = "terraform"
  }
}
