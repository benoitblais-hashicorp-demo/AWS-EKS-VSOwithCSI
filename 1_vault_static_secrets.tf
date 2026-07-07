# Copyright IBM Corp. 2024, 2026

resource "vault_mount" "credentials" {
  namespace   = vault_namespace.namespace.path
  path        = "creds"
  type        = "kv"
  description = "KV v2 mount for credentials"
  options = {
    version = "2"
  }
}

resource "vault_generic_secret" "credentials" {
  namespace = vault_namespace.namespace.path
  path      = "${vault_mount.credentials.path}/app/config"
  data_json = jsonencode({
    message   = "Try VSO with CSI by changing this text from Vault!"
    image_url = "/resources/logo.png"
  })
}
