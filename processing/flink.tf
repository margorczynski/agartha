resource "helm_release" "flink_operator" {
  namespace  = local.flink_namespace
  name       = "flink"
  repository = "https://downloads.apache.org/flink/flink-kubernetes-operator-1.8.0"
  chart      = "flink-kubernetes-operator"

  set_list {
    name  = "watchNamespaces"
    value = [ local.flink_namespace ]
  }

  set {
    name  = "webhook.create"
    value = "false"
  }
}