# Copyright IBM Corp. 2024, 2026

locals {
  demo_name        = "secrets-operator"
  global_id        = random_string.identifier.result
  resources_prefix = "${var.resources_prefix}-${local.global_id}"
}

resource "random_string" "identifier" {
  length  = 4
  special = false
  numeric = false
  upper   = false
}
