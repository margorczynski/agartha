# ConfigMap containing the Agartha realm configuration for Keycloak import
resource "kubernetes_config_map_v1" "keycloak_realm" {
  metadata {
    name      = "keycloak-realm-config"
    namespace = local.namespace
  }

  data = {
    "agartha-realm.json" = templatefile("${path.module}/templates/realm.json.tftpl", {
      grafana_client_secret  = var.grafana_oauth_client_secret
      superset_client_secret = var.superset_oauth_client_secret
      trino_client_secret    = var.trino_oauth_client_secret
      ingress_base_host      = var.kubernetes_ingress_base_host
    })
  }

  depends_on = [
    kubernetes_namespace_v1.identity_namespace
  ]
}
