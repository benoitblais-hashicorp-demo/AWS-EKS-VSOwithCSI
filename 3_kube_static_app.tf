# Copyright IBM Corp. 2024, 2026

# ==============================================================================
# DEMO WEB APPLICATION & SECRETS INJECTION
# ==============================================================================
# This file provisions the core Go web application and configures the Vault 
# Secrets Operator CSI provider to inject Vault secrets directly into the 
# application pods as ephemeral volume mounts. It also sets up a CronJob to 
# periodically restart the deployment, demonstrating dynamic secret retrieval 
# without storing sensitive data in native Kubernetes Secrets.
# This execution is gated by the step_3 variable.
# ==============================================================================

# ------------------------------------------------------------------------------
# VAULT SECRETS OPERATOR (CSI INTEGRATION)
# ------------------------------------------------------------------------------

# 1. Provide VSO with instructions on which internal Vault path to sync via CSI
resource "kubernetes_manifest" "vault_csi_secret" {
  count = var.step_3 ? 1 : 0
  depends_on = [
    time_sleep.step_3,
    helm_release.vault_secrets_operator,
    vault_generic_secret.webapp_config,
  ]

  field_manager {
    force_conflicts = true
  }

  manifest = yamldecode(<<-EOF
apiVersion: secrets.hashicorp.com/v1beta1
kind: CSISecrets
metadata:
  name: csi-secret
  namespace: ${kubernetes_namespace_v1.demo_app[0].metadata.0.name}
spec:
  namespace: ${trim(vault_namespace.namespace.id, "/")}
  accessControl:
    matchPolicy: any
    serviceAccountPattern: "${kubernetes_service_account_v1.vault[0].metadata.0.name}"
    namespacePatterns:
      - "${kubernetes_namespace_v1.demo_app[0].metadata.0.name}"
  vaultAuthRef:
    name: default
    namespace: ${kubernetes_namespace_v1.demo_app[0].metadata.0.name}
  secrets:
    vaultStaticSecrets:
      - mount: ${vault_mount.webapp.path}
        type: kv-v2
        path: app/config
        refreshAfter: 5s
EOF
  )
}

# ------------------------------------------------------------------------------
# APPLICATION DEPLOYMENT & SERVICE
# ------------------------------------------------------------------------------

# 2. Deploy the web application pods and mount the dynamic CSI volume containing the secrets
resource "kubernetes_deployment_v1" "demo_webapp" {
  count            = var.step_3 ? 1 : 0
  wait_for_rollout = false
  depends_on = [
    time_sleep.step_3,
    kubernetes_manifest.vault_csi_secret,
  ]
  metadata {
    name      = "demo-webapp"
    namespace = kubernetes_namespace_v1.demo_app[0].metadata.0.name
  }

  spec {
    replicas = 3

    strategy {
      rolling_update {
        max_unavailable = 1
      }
    }

    selector {
      match_labels = {
        app = "demo-webapp"
      }
    }

    template {
      metadata {
        labels = {
          app = "demo-webapp"
        }
        annotations = {
          "kubectl.kubernetes.io/restartedAt" = var.static_app_rollout_token != "" ? var.static_app_rollout_token : "initial-deploy"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.vault[0].metadata.0.name
        container {
          name              = "demo-webapp"
          image             = var.demo_webapp_image
          image_pull_policy = "Always"
          port {
            container_port = 8080
          }

          resources {
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          liveness_probe {
            http_get {
              path   = "/health"
              scheme = "HTTP"
              port   = 8080
            }
          }

          volume_mount {
            mount_path = "/var/run/secrets/vault"
            name       = "vso-csi"
          }

          env {
            name  = "TITLE"
            value = "Vault Secrets Operator + CSI Integration!"
          }

          env {
            name  = "SUB_TITLE"
            value = "You are now managing static secrets via CSI using Volume Mounts."
          }

          env {
            name  = "LEARN_LINK"
            value = "https://developer.hashicorp.com/vault/docs/platform/k8s/vso/csi"
          }
        }

        volume {
          name = "vso-csi"
          csi {
            read_only = true
            driver    = "csi.vso.hashicorp.com"
            volume_attributes = {
              csiSecretsName      = "csi-secret"
              csiSecretsNamespace = kubernetes_namespace_v1.demo_app[0].metadata.0.name
            }
          }
        }


      }
    }
  }
}

# 3. Expose the web application internally within the Kubernetes cluster
resource "kubernetes_service_v1" "demo_webapp" {
  count      = var.step_3 ? 1 : 0
  depends_on = [time_sleep.step_3]
  metadata {
    name      = kubernetes_deployment_v1.demo_webapp[0].metadata.0.name
    namespace = kubernetes_namespace_v1.demo_app[0].metadata.0.name
  }

  spec {
    type = "ClusterIP"

    port {
      port        = 8080
      target_port = 8080
    }

    selector = {
      app = "demo-webapp"
    }
  }
}

# ------------------------------------------------------------------------------
# AUTOMATED POD RESTARTER (CRONJOB)
# ------------------------------------------------------------------------------

# 4. Create a dedicated Service Account for the cronjob pod restarter
resource "kubernetes_service_account_v1" "restarter" {
  count      = var.step_3 ? 1 : 0
  depends_on = [time_sleep.step_3]
  metadata {
    name      = "pod-restarter"
    namespace = kubernetes_namespace_v1.demo_app[0].metadata.0.name
  }
}

# 5. Grant permissions to execute a "deployment rollout restart"
resource "kubernetes_role_v1" "restarter" {
  count      = var.step_3 ? 1 : 0
  depends_on = [time_sleep.step_3]
  metadata {
    name      = "pod-restarter"
    namespace = kubernetes_namespace_v1.demo_app[0].metadata.0.name
  }
  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "patch", "list"]
  }
}

# 6. Bind the rollout restart permissions to the cronjob's Service Account
resource "kubernetes_role_binding_v1" "restarter" {
  count      = var.step_3 ? 1 : 0
  depends_on = [time_sleep.step_3]
  metadata {
    name      = "pod-restarter"
    namespace = kubernetes_namespace_v1.demo_app[0].metadata.0.name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.restarter[0].metadata.0.name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.restarter[0].metadata.0.name
    namespace = kubernetes_namespace_v1.demo_app[0].metadata.0.name
  }
}

# 7. Configure a CronJob that triggers `kubectl rollout restart deployment/demo-webapp` every minute
resource "kubernetes_cron_job_v1" "restarter" {
  count      = var.step_3 ? 1 : 0
  depends_on = [time_sleep.step_3]
  metadata {
    name      = "demo-webapp-restarter"
    namespace = kubernetes_namespace_v1.demo_app[0].metadata.0.name
  }
  spec {
    schedule = "* * * * *"
    job_template {
      metadata {}
      spec {
        template {
          metadata {}
          spec {
            service_account_name = kubernetes_service_account_v1.restarter[0].metadata.0.name
            container {
              name    = "kubectl"
              image   = "bitnami/kubectl:latest"
              command = ["kubectl", "rollout", "restart", "deployment/demo-webapp"]
            }
            restart_policy = "OnFailure"
          }
        }
      }
    }
  }
}
