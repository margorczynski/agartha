resource "helm_release" "spark_operator" {
  namespace  = local.spark_namespace
  name       = "spark"
  repository = "https://kubeflow.github.io/spark-operator"
  chart      = "spark-operator"
  version    = "1.1.27"

  set {
    name  = "sparkJobNamespace"
    value = local.spark_namespace
  }

  set {
    name  = "webhook.enable"
    value = "true"
  }

  set {
    name  = "sparkUIOptions.ingressAnnotations.kubernetes\\.io/ingress.class"
    value = "nginx"
  }

  set {
    name  = "ingressUrlFormat"
    value = "spark.agartha.minikubehost.com/{{$appName}}"
  }
}