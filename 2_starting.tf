# Copyright IBM Corp. 2024, 2026

resource "time_sleep" "step_2" {
  count = var.step_2 ? 1 : 0
  depends_on = [
    module.eks,
    module.vpc,
    vault_generic_secret.credentials,
  ]
  create_duration  = "10s"
  destroy_duration = "10s"
}
