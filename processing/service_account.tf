resource "kubernetes_service_account" "spark_sa" {
  metadata {
    name      = "spark-sa"
    namespace = local.spark_namespace
  }
}

resource "kubernetes_cluster_role_binding" "spark_sa_role" {
  metadata {
    name = "spark-sa-role"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "edit"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "spark-sa"
    namespace = local.spark_namespace
  }
}