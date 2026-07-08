# Copyright IBM Corp. 2024, 2026

resource "vault_policy" "apps_policy" {
  count      = var.step_2 ? 1 : 0
  depends_on = [time_sleep.step_2]
  namespace  = vault_namespace.namespace.path
  name       = "apps-policy"

  policy = <<EOT
path "${vault_mount.webapp.path}/*" {
  capabilities = ["create", "read", "update", "patch", "list"]
}

# Vault Secrets Operator CSI driver actively requires Vault Enterprise.
# It identifies Vault Enterprise by checking the `/sys/license/status` endpoint
# using the Pod's authenticated identity. We must grant read access.
path "sys/license/status" {
  capabilities = ["read"]
}
EOT
}
