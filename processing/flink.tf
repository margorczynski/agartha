resource "helm_release" "flink_operator" {
  namespace  = local.flink_namespace
  name       = "flink"
  repository = "https://archive.apache.org/dist/flink/flink-kubernetes-operator-1.8.0"
  chart      = "flink-kubernetes-operator"

  timeout = 600 # 10 minutes for image pulls on slow connections

  set_list = [
    {
      name  = "watchNamespaces"
      value = [local.flink_namespace]
    }
  ]

  set = [
    {
      name  = "webhook.create"
      value = "false"
    }
  ]

  depends_on = [
    kubernetes_namespace_v1.processing_namespace_flink
  ]
}