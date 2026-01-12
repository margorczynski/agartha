resource "random_password" "superset_secret_key" {
  length           = 42
  special          = true
  override_special = "+/"
}

resource "kubernetes_secret_v1" "secret_superset_secret_key" {
  metadata {
    name      = "superset-secret-key"
    namespace = var.kubernetes_bi_namespace
  }

  data = {
    "SECRET_KEY" = random_password.superset_secret_key.result
  }

  depends_on = [
    kubernetes_namespace_v1.bi_namespace
  ]
}

resource "helm_release" "superset" {
  namespace  = var.kubernetes_bi_namespace
  name       = "superset"
  repository = "https://apache.github.io/superset"
  chart      = "superset"

  set = [
    {
      name  = "configOverrides.secret"
      value = "SECRET_KEY = '${random_password.superset_secret_key.result}'"
    },
    {
      name  = "supersetNode.replicaCount"
      value = var.superset_node_replica_num
    },
    {
      name  = "supersetWorker.replicaCount"
      value = var.superset_worker_replica_num
    },
    {
      name  = "bootstrapScript"
      value = file("${path.module}/files/superset_bootstrap_script.sh")
    },
    {
      name  = "extraConfigs.import_datasources\\.yaml"
      value = file("${path.module}/files/superset_import_agartha.yaml")
    },
    {
      name  = "postgresql.image.tag"
      value = "latest"
    },
    {
      name  = "redis.image.tag"
      value = "latest"
    }
  ]

  depends_on = [
    kubernetes_namespace_v1.bi_namespace
  ]
}