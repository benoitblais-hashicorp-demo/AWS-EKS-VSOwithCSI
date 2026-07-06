# Copyright IBM Corp. 2024, 2026

resource "helm_release" "vault_secrets_operator" {
  count      = var.step_2 ? 1 : 0
  depends_on = [time_sleep.step_2]
  name       = "vault-secrets-operator"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault-secrets-operator"
  namespace  = kubernetes_namespace_v1.simple_app[0].metadata.0.name
  version    = "1.3.0"
  values = [<<-EOT
  defaultVaultConnection:
    enabled: false
  defaultAuthMethod:
    enabled: false
  csi:
    enabled: true
EOT
  ]
}

resource "kubernetes_manifest" "vault_connection" {
  count = var.step_2 ? 1 : 0
  depends_on = [
    time_sleep.step_2,
    helm_release.vault_secrets_operator,
  ]

  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultConnection"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace_v1.simple_app[0].metadata.0.name
    }
    spec = {
      address = var.vault_address
    }
  }
}

resource "kubernetes_manifest" "vault_auth" {
  count = var.step_2 ? 1 : 0
  depends_on = [
    time_sleep.step_2,
    helm_release.vault_secrets_operator,
    kubernetes_manifest.vault_connection,
    vault_kubernetes_auth_backend_role.simple_app_role,
  ]

  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultAuth"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace_v1.simple_app[0].metadata.0.name
    }
    spec = {
      vaultConnectionRef = kubernetes_manifest.vault_connection[0].manifest.metadata.name
      namespace          = vault_namespace.namespace.path_fq
      method             = vault_auth_backend.kube_auth[0].type
      mount              = vault_auth_backend.kube_auth[0].path
      kubernetes = {
        role           = vault_kubernetes_auth_backend_role.simple_app_role[0].role_name
        serviceAccount = kubernetes_service_account_v1.vault[0].metadata.0.name
        audiences      = ["vault"]
      }
    }
  }
}
