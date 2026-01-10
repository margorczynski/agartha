provider "kubernetes" {
  config_path = "${var.kubernetes_config_path}"
}

provider "helm" {
  kubernetes = {
    config_path = "${var.kubernetes_config_path}"
  }
}