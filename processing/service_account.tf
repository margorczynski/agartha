resource "kubernetes_service_account_v1" "spark_sa" {
  metadata {
    name      = "spark-sa"
    namespace = local.spark_namespace
  }

  depends_on = [
    kubernetes_namespace_v1.processing_namespace_spark
  ]
}

resource "kubernetes_role_v1" "spark_runner" {
  metadata {
    name      = "spark-runner"
    namespace = local.spark_namespace
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["create", "delete", "get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log", "pods/status"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["services"]
    verbs      = ["create", "delete", "get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["create", "delete", "get", "list", "watch", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["create"]
  }

  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_role_binding_v1" "spark_sa_role" {
  metadata {
    name      = "spark-sa-role"
    namespace = local.spark_namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.spark_runner.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = "spark-sa"
    namespace = local.spark_namespace
  }

  depends_on = [
    kubernetes_service_account_v1.spark_sa,
    kubernetes_role_v1.spark_runner
  ]
}