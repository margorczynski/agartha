resource "helm_release" "spark_operator" {
  namespace  = local.spark_namespace
  name       = "spark"
  repository = "https://kubeflow.github.io/spark-operator"
  chart      = "spark-operator"
  version    = "1.1.27"

  timeout = 600 # 10 minutes for image pulls on slow connections

  set = [
    {
      name  = "sparkJobNamespace"
      value = local.spark_namespace
    },
    {
      name  = "webhook.enable"
      value = "true"
    },
    {
      name  = "sparkUIOptions.ingressAnnotations.kubernetes\\.io/ingress.class"
      value = "nginx"
    },
    {
      name  = "ingressUrlFormat"
      value = "spark.agartha.minikubehost.com/{{$appName}}"
    }
  ]

  depends_on = [
    kubernetes_namespace_v1.processing_namespace_spark
  ]
}