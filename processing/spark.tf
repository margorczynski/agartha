resource "helm_release" "spark_operator" {
  namespace  = local.spark_namespace
  name       = "spark"
  repository = "https://kubeflow.github.io/spark-operator"
  chart      = "spark-operator"

  set {
    name  = "sparkJobNamespace"
    value = local.spark_namespace
  }

  set {
    name  = "webhook.enable"
    value = "true"
  }
}