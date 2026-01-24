resource "kubernetes_secret_v1" "keycloak_database_password" {
  metadata {
    name      = "keycloak-database-password"
    namespace = local.namespace
  }

  data = {
    "password" = var.keycloak_postgres_password
  }

  depends_on = [
    kubernetes_namespace_v1.identity_namespace
  ]
}

resource "helm_release" "keycloak" {
  namespace  = local.namespace
  name       = "keycloak"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "keycloak"
  version    = "25.2.0"

  timeout = 600

  set = [
    {
      name  = "global.security.allowInsecureImages"
      value = "true"
    },
    {
      name  = "auth.adminUser"
      value = "admin"
    },
    {
      name  = "auth.adminPassword"
      value = var.keycloak_admin_password
    },
    {
      name  = "auth.createAdminUser"
      value = "true"
    },
    {
      name  = "replicaCount"
      value = tostring(var.keycloak_replicas)
    },
    {
      name  = "service.ports.http"
      value = "80"
    },
    {
      name  = "ingress.enabled"
      value = "false"
    },
    {
      name  = "ingress.hostname"
      value = local.keycloak_host
    },
    {
      name  = "ingress.ingressClassName"
      value = "nginx"
    },
    {
      name  = "ingress.pathType"
      value = "Prefix"
    },
    {
      name  = "ingress.path"
      value = "/"
    },
    {
      name  = "ingress.tls"
      value = "false"
    },
    {
      name  = "proxy"
      value = "edge"
    },
    {
      name  = "hostname"
      value = local.keycloak_host
    },
    # Enable strict hostname mode to ensure consistent issuer URLs
    {
      name  = "hostnameStrict"
      value = "true"
    },
    {
      name  = "image.pullPolicy"
      value = "IfNotPresent"
    },
    {
      name  = "image.registry"
      value = "docker.io"
    },
    {
      name  = "image.repository"
      value = "bitnamilegacy/keycloak"
    },
    {
      name  = "image.tag"
      value = "26.3.3-debian-12-r0"
    },
    {
      name  = "postgresql.enabled"
      value = "true"
    },
    {
      name  = "postgresql.auth.password"
      value = var.keycloak_postgres_password
    },
    {
      name  = "postgresql.image.registry"
      value = "docker.io"
    },
    {
      name  = "postgresql.image.repository"
      value = "bitnamilegacy/postgresql"
    },
    {
      name  = "postgresql.image.tag"
      value = "17.6.0-debian-12-r0"
    },
    {
      name  = "postgresql.primary.persistence.enabled"
      value = "true"
    },
    {
      name  = "postgresql.primary.persistence.size"
      value = "${tostring(var.keycloak_postgres_storage_size_gb)}Gi"
    },
    {
      name  = "postgresql.volumePermissions.enabled"
      value = "true"
    },
    {
      name  = "postgresql.volumePermissions.image.registry"
      value = "docker.io"
    },
    {
      name  = "postgresql.volumePermissions.image.repository"
      value = "bitnamilegacy/os-shell"
    },
    {
      name  = "postgresql.volumePermissions.image.tag"
      value = "12-debian-12-r50"
    },
    {
      name  = "resources.limits.cpu"
      value = "1000m"
    },
    {
      name  = "resources.limits.memory"
      value = "2Gi"
    },
    {
      name  = "resources.requests.cpu"
      value = "500m"
    },
    {
      name  = "resources.requests.memory"
      value = "1Gi"
    },
    # Disable keycloakConfigCli - we use native realm import instead
    {
      name  = "keycloakConfigCli.enabled"
      value = "false"
    },
    # Native realm import on startup
    {
      name  = "extraEnvVars[0].name"
      value = "KEYCLOAK_EXTRA_ARGS"
    },
    {
      name  = "extraEnvVars[0].value"
      value = "--import-realm"
    },
    # Explicitly set the hostname for Keycloak
    # This ensures tokens have a consistent issuer URL regardless of how Keycloak is accessed
    {
      name  = "extraEnvVars[1].name"
      value = "KC_HOSTNAME"
    },
    {
      name  = "extraEnvVars[1].value"
      value = local.keycloak_host
    },
    # Ensure Keycloak uses the external hostname for tokens even when accessed internally
    # This is required for OAuth2 integrations where services call Keycloak via internal URLs
    {
      name  = "extraEnvVars[2].name"
      value = "KC_HOSTNAME_STRICT_BACKCHANNEL"
    },
    {
      name  = "extraEnvVars[2].value"
      type  = "string"
      value = "true"
    },
    {
      name  = "extraVolumes[0].name"
      value = "realm-config"
    },
    {
      name  = "extraVolumes[0].configMap.name"
      value = kubernetes_config_map_v1.keycloak_realm.metadata[0].name
    },
    {
      name  = "extraVolumeMounts[0].name"
      value = "realm-config"
    },
    {
      name  = "extraVolumeMounts[0].mountPath"
      value = "/opt/bitnami/keycloak/data/import"
    },
    {
      name  = "extraVolumeMounts[0].readOnly"
      value = "true"
    }
  ]

  depends_on = [
    kubernetes_namespace_v1.identity_namespace,
    kubernetes_secret_v1.keycloak_database_password,
    kubernetes_config_map_v1.keycloak_realm
  ]
}
