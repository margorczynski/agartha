resource "random_password" "superset_secret_key" {
  length           = 42
  special          = true
  override_special = "+/"
}

resource "kubernetes_secret" "secret_superset_secret_key" {
  metadata {
    name      = "superset-secret-key"
    namespace = var.kubernetes_bi_namespace
  }

  data = {
    "SECRET_KEY" = random_password.superset_secret_key.result
  }
}

resource "helm_release" "superset" {
  namespace  = var.kubernetes_bi_namespace
  name       = "superset"
  repository = "https://apache.github.io/superset"
  chart      = "superset"

set {
    name =  "configOverrides.secret"
    value = "SECRET_KEY = '${random_password.superset_secret_key.result}'"
  }

  set {
    name =  "supersetNode.replicaCount"
    value = var.superset_node_replica_num
  }

  set {
    name =  "supersetWorker.replicaCount"
    value = var.superset_worker_replica_num
  }

  set {
    name =  "bootstrapScript"
    value = file("${path.module}/files/superset_bootstrap_script.sh")
  }

  set {
    name =  "extraConfigs.import_datasources\\.yaml"
    value = file("${path.module}/files/superset_import_agartha.yaml")
  }
}