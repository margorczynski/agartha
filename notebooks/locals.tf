locals {
  namespace = var.kubernetes_notebooks_namespace

  jupyter_labels = {
    "app.kubernetes.io/name"       = "jupyter"
    "app.kubernetes.io/component"  = "notebooks"
    "app.kubernetes.io/managed-by" = "terraform"
  }

  jupyter_host = "jupyter.${var.kubernetes_ingress_base_host}"
}
