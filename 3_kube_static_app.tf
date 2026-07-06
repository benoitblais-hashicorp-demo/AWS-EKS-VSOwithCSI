# Copyright IBM Corp. 2024, 2026

resource "kubernetes_manifest" "vault_csi_secret" {
  count = var.step_3 ? 1 : 0
  depends_on = [
    time_sleep.step_3,
    helm_release.vault_secrets_operator,
    kubernetes_manifest.vault_auth,
    vault_generic_secret.credentials,
  ]
  manifest = yamldecode(<<-EOF
apiVersion: secrets.hashicorp.com/v1beta1
kind: CSISecrets
metadata:
  name: csi-secret
  namespace: ${kubernetes_namespace_v1.simple_app[0].metadata.0.name}
spec:
  namespace: ${vault_namespace.namespace.id}
  accessControl:
    serviceAccountPattern: ".*"
    namespacePatterns:
      - ".*"
  vaultAuthRef:
    name: default
    namespace: ${kubernetes_namespace_v1.simple_app[0].metadata.0.name}
  secrets:
    vaultStaticSecrets:
      - mount: ${vault_mount.credentials.path}
        type: kv-v2
        path: app/config
EOF
  )
}

resource "kubernetes_deployment_v1" "static_app" {
  count            = var.step_3 ? 1 : 0
  wait_for_rollout = false
  depends_on = [
    time_sleep.step_3,
    kubernetes_manifest.vault_csi_secret,
  ]
  metadata {
    name      = "static-secrets"
    namespace = kubernetes_namespace_v1.simple_app[0].metadata.0.name
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
        app = "static-secrets"
      }
    }

    template {
      metadata {
        labels = {
          app = "static-secrets"
        }
        annotations = {
          "kubectl.kubernetes.io/restartedAt" = var.static_app_rollout_token != "" ? var.static_app_rollout_token : "initial-deploy"
        }
      }

      spec {
        service_account_name = kubernetes_service_account_v1.vault[0].metadata.0.name
        container {
          name  = "static-secrets"
          image = "drum0r/demo-go-web:v1.1.0"
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
              csiSecretsNamespace = kubernetes_namespace_v1.simple_app[0].metadata.0.name
            }
          }
        }


      }
    }
  }
}

resource "kubernetes_service_v1" "static_app" {
  count      = var.step_3 ? 1 : 0
  depends_on = [time_sleep.step_3]
  metadata {
    name      = kubernetes_deployment_v1.static_app[0].metadata.0.name
    namespace = kubernetes_namespace_v1.simple_app[0].metadata.0.name
  }

  spec {
    type = "ClusterIP"

    port {
      port        = 8080
      target_port = 8080
    }

    selector = {
      app = "static-secrets"
    }
  }
}
