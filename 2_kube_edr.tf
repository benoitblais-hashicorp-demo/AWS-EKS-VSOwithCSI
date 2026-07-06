# Copyright IBM Corp. 2024, 2026

resource "kubernetes_namespace_v1" "edr" {
  count      = var.step_2 ? 1 : 0
  depends_on = [time_sleep.step_2]
  metadata {
    name = "uptycs"
    labels = {
      "app.kubernetes.io/managed-by"   = "terraform"
      "security.hashicorp.com/cluster" = module.eks.cluster_name
      "security.hashicorp.com/addons"  = "edr"
      "security.hashicorp.com/rbac"    = "edr"
    }
  }
}

resource "helm_release" "uptycs_edr" {
  count            = var.step_2 ? 1 : 0
  depends_on       = [kubernetes_namespace_v1.edr]
  name             = "uptycs-edr"
  repository       = "https://uptycslabs.github.io/kspm-helm-charts"
  chart            = "k8sosquery"
  namespace        = kubernetes_namespace_v1.edr[0].metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 900

  values = [
    yamlencode({
      configmap = {
        name = "uptycs-config"
        data = {
          tags = var.uptycs_tags
        }
      }
    })
  ]
}
