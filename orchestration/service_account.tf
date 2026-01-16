resource "kubernetes_service_account_v1" "dagster_sa" {
  metadata {
    name      = "dagster-sa"
    namespace = local.namespace
    labels    = local.dagster_labels
  }

  depends_on = [
    kubernetes_namespace_v1.orchestration_namespace
  ]
}

# Allow Dagster to create and manage jobs in its own namespace
resource "kubernetes_role_v1" "dagster_job_runner" {
  metadata {
    name      = "dagster-job-runner"
    namespace = local.namespace
    labels    = local.dagster_labels
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log", "pods/status"]
    verbs      = ["get", "list", "watch", "create", "delete"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch", "create", "delete", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "secrets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["create", "patch"]
  }

  depends_on = [
    kubernetes_namespace_v1.orchestration_namespace
  ]
}

resource "kubernetes_role_binding_v1" "dagster_job_runner_binding" {
  metadata {
    name      = "dagster-job-runner-binding"
    namespace = local.namespace
    labels    = local.dagster_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.dagster_job_runner.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.dagster_sa.metadata[0].name
    namespace = local.namespace
  }
}

# Allow Dagster to submit Spark jobs to the Spark namespace
resource "kubernetes_role_v1" "dagster_spark_submitter" {
  metadata {
    name      = "dagster-spark-submitter"
    namespace = var.spark_namespace
    labels    = local.dagster_labels
  }

  rule {
    api_groups = ["sparkoperator.k8s.io"]
    resources  = ["sparkapplications", "scheduledsparkapplications"]
    verbs      = ["get", "list", "watch", "create", "delete", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "dagster_spark_submitter_binding" {
  metadata {
    name      = "dagster-spark-submitter-binding"
    namespace = var.spark_namespace
    labels    = local.dagster_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.dagster_spark_submitter.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.dagster_sa.metadata[0].name
    namespace = local.namespace
  }
}

# Allow Dagster to submit Flink jobs to the Flink namespace
resource "kubernetes_role_v1" "dagster_flink_submitter" {
  metadata {
    name      = "dagster-flink-submitter"
    namespace = var.flink_namespace
    labels    = local.dagster_labels
  }

  rule {
    api_groups = ["flink.apache.org"]
    resources  = ["flinkdeployments", "flinksessionjobs"]
    verbs      = ["get", "list", "watch", "create", "delete", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding_v1" "dagster_flink_submitter_binding" {
  metadata {
    name      = "dagster-flink-submitter-binding"
    namespace = var.flink_namespace
    labels    = local.dagster_labels
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.dagster_flink_submitter.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.dagster_sa.metadata[0].name
    namespace = local.namespace
  }
}
