# Copyright IBM Corp. 2024, 2026

resource "vault_namespace" "namespace" {
  path = "${local.demo_id}-ns"
}
