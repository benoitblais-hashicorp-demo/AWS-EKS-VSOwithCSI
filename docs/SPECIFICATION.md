# Technical Specification: AWS EKS with Vault Secrets Operator + CSI Integration

## Overview

This document describes the technical architecture, design decisions, and operational flow for the AWS EKS + VSO + CSI demo. The configuration demonstrates how HashiCorp Vault secrets can be delivered securely and directly into Kubernetes pod workloads using the Vault Secrets Operator (VSO) CSI provider — without ever creating a Kubernetes `Secret` object.

---

## Architecture

```text
┌─────────────────────────────────────────────────────────────────┐
│                         HCP Terraform                           │
│  (VCS-driven, dynamic AWS + Vault credentials, 3-step apply)   │
└─────────────────────────┬───────────────────────────────────────┘
                          │ terraform apply (step_1)
          ┌───────────────▼───────────────┐
          │         AWS (ca-central-1)     │
          │  ┌─────────────────────────┐  │
          │  │      VPC (10.0.0.0/16)  │  │
          │  │  Private + Public Subnets│  │
          │  │  NAT Gateway            │  │
          │  └──────────┬──────────────┘  │
          │             │                  │
          │  ┌──────────▼──────────────┐  │
          │  │  EKS Cluster (1.34)     │  │
          │  │  Managed Node Group     │  │
          │  │  (t3.medium, 1–3 nodes) │  │
          │  └──────────┬──────────────┘  │
          └─────────────│─────────────────┘
                        │ step_2
          ┌─────────────▼─────────────────────────┐
          │          Kubernetes (EKS)               │
          │  namespaces: demo-go-web-vso-csi, ingress-nginx, uptycs │
          │  ┌─────────────────────────────────────────┐  │
          │  │  helm: ingress-nginx (NLB + EIP)        │  │
          │  │  helm: k8sosquery (Uptycs EDR)          │  │
          │  │  helm: vault-secrets-operator           │  │
          │  │    └─ CSI provider enabled               │  │
          │  │  ServiceAccount: vault-auth              │  │
          │  │  ClusterRoleBinding: token-review        │  │
          │  └─────────────────────────────────────────┘  │
          └───────────────────────────────────────────── ┘
                        │ step_3
          ┌─────────────▼─────────────────────────────────────────┐
          │          Kubernetes (EKS) — Application Layer           │
          │                                                         │
          │  CSISecrets CR ──────────────► VSO CSI Driver           │
          │  (csi.vso.hashicorp.com)         │                      │
          │                                  ▼                      │
          │  Pod (demo-webapp)      Vault KV read                │
          │  └─ volumeMount:           (webapp/app/config)           │
          │     /var/run/secrets/vault                              │
          └─────────────────────────────────────────────────────── ┘
                        │ reads KV secret
          ┌─────────────▼──────────────────┐
          │       HashiCorp Vault            │
          │  Namespace: <demo_id>-ns         │
          │  KV v2 mount: webapp              │
          │  Secret: webapp/app/config        │
          │    message: "Try VSO by..."      │
          │    image_url: "/resources/..."   │
          └──────────────────────────────── ┘
```

---

## Deployment Steps

This demo uses a three-step gated deployment pattern. Steps are controlled by boolean Terraform variables (`step_2`, `step_3`) to ensure that the EKS cluster and Vault resources are stable before building dependent layers on top of them.

### Step 1 — Infrastructure and Secrets (default)

Resources provisioned:

| Resource | Description |
| --- | --- |
| `module.vpc` | AWS VPC, private/public subnets across up to 3 AZs, NAT Gateway |
| `module.eks` | EKS cluster v1.34, managed node group, core addons |
| `vault_namespace.namespace` | Isolated Vault namespace scoped to this demo |
| `vault_mount.webapp` | KV v2 secrets engine mounted at `webapp` |
| `vault_generic_secret.webapp` | Static secret at `webapp/app/config` |

After Step 1, the AWS infrastructure is provisioned and the initial Vault secret is populated.

### Step 2 — Kubernetes Tooling (`step_2 = true`)

Resources provisioned:

| Resource | Description |
| --- | --- |
| `kubernetes_namespace_v1.demo_app` | Dedicated namespaces (`demo-go-web-vso-csi`, `ingress-nginx`, `uptycs`) with PSS compliance |
| `aws_eip.nginx_ingress` | 3 Elastic IPs for the Network Load Balancer |
| `helm_release.nginx_ingress` | Nginx ingress controller (internet-facing NLB) |
| `helm_release.uptycs_edr` | IBM Uptycs EDR agent (k8sosquery Helm chart) |
| `helm_release.vault_secrets_operator` | VSO Helm chart v1.3.0 with CSI driver enabled |
| `kubernetes_service_account_v1.vault` | Service account `vault-auth` for Vault authentication |
| `kubernetes_secret_v1.vault_token` | Long-lived service account token for Vault token reviewer |
| `kubernetes_cluster_role_binding_v1.vault` | Binds `system:auth-delegator` for token review |
| `vault_auth_backend.kube_auth` | Vault Kubernetes auth backend |
| `vault_kubernetes_auth_backend_config.kube_auth_cfg` | Configured with EKS CA cert and endpoint |
| `vault_kubernetes_auth_backend_role.demo_app_role` | Role `demo-go-web-vso-csi` bound to `vault-auth` service account |
| `vault_policy.apps_policy` | Policy granting read access to `webapp/*` |

After Step 2, the VSO operator is running with the CSI driver sidecar, and Vault Kubernetes authentication is fully wired.

### Step 3 — Application Deployment (`step_3 = true`)

Resources provisioned:

| Resource | Description |
| --- | --- |
| `kubernetes_manifest.vault_csi_secret` | `CSISecrets` CR referencing `webapp/app/config` |
| `kubernetes_deployment_v1.demo_webapp` | Go web app (`drum0r/demo-go-web:v1.1.0`), 3 replicas |
| `kubernetes_service_v1.demo_webapp` | ClusterIP service exposing port 8080 |
| `kubernetes_ingress_v1.apps` | Ingress rule routing `/` to the static app |

After Step 3, the web application is accessible via the Elastic IP and renders Vault secret content directly from the CSI-mounted volume.

---

## Secret Delivery Mechanism

### How Secrets Reach the Pod

The VSO CSI integration delivers secrets as ephemeral volume files mounted into the pod filesystem. The flow is:

```text
Vault KV Secret
      │
      ▼
VSO reads secret using Kubernetes auth (service account JWT token)
      │
      ▼
VSO CSI Driver (csi.vso.hashicorp.com) writes secret data to ephemeral volume
      │
      ▼
Pod mounts volume at /var/run/secrets/vault
      │
      ▼
Application reads secret as a file (e.g., /var/run/secrets/vault/message)
```

Key properties:

- **No Kubernetes Secret object is created.** The secret data never enters the Kubernetes API server as a persistent object.
- **Secret data is ephemeral.** The CSI volume exists only for the lifetime of the pod. When the pod terminates, the mounted secret data is removed.
- **Vault is the single source of truth.** The application always reads from a Vault-backed volume, not a cached copy.

### CSISecrets Custom Resource

The `CSISecrets` custom resource (CRD installed by VSO) declares which Vault paths should be surfaced by the CSI driver:

```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: CSISecrets
metadata:
  name: csi-secret
  namespace: demo-go-web-vso-csi
spec:
  vaultAuthRef: default
  secrets:
    vaultStaticSecrets:
      - mount: webapp
        path: app/config
        metadata:
          name: app-config
```

When a pod references the CSI driver with `csiSecretsName: csi-secret`, VSO authenticates to Vault, retrieves the KV secret, and injects it into the pod's ephemeral volume at mount time.

---

## Secret Rotation

### What Happens When a Secret is Rotated

When the Vault secret at `webapp/app/config` is updated (e.g., `message` field changed), the following sequence occurs:

1. **Vault stores the new secret version.** KV v2 retains previous versions; the new version becomes the current default.
2. **VSO detects the change.** The VSO operator continuously reconciles `CSISecrets` resources and polls Vault for updates based on its refresh interval.
3. **VSO updates the CSI node staging.** The updated secret data is written to the ephemeral CSI staging area on the node.
4. **Running pods do NOT automatically pick up the change.** Because the secret is a CSI volume (not a projected volume), running pods continue to see the original data.
5. **After a pod restart, the new secret is visible.** When a pod is restarted (rolling update, node eviction, or manual deletion), the new CSI volume is mounted with the current Vault secret.

### Demo: Rotating a Secret

To demonstrate secret rotation in the live demo:

1. Navigate to the Vault UI using the `vault_address` output and switch to the namespace shown in `vault_namespace`.
2. Go to **Secrets > webapp > app/config** and click **Create new version**.
3. Update the `message` field to a new value and save.
4. Observe that the running web application still shows the old value (CSI volume is not live-reloaded).
5. Delete one or more pods to trigger a restart: `kubectl rollout restart deployment/demo-webapp -n demo-go-web-vso-csi`.
6. Reload the web application — the new message from Vault is now displayed.

This behavior makes the rotation process deliberate and controlled: secrets update only when pods restart, providing a predictable and auditable change window.

---

## Networking

### Ingress Architecture

The nginx ingress controller is deployed with an internet-facing AWS Network Load Balancer (NLB). Three Elastic IPs are pre-allocated and associated with the NLB via `service.beta.kubernetes.io/aws-load-balancer-eip-allocations`. This ensures a stable, predictable public IP for the demo application.

Traffic flow:

```text
Internet → Elastic IP (NLB) → nginx ingress controller → demo-go-web-vso-csi service → pod (port 8080)
```

### EKS Cluster Networking

The EKS cluster uses private subnets for worker nodes. The control plane endpoint is publicly accessible (`endpoint_public_access = true`) to allow Terraform (running in HCP Terraform) to configure the cluster. In production, this should be set to private-only.

---

## Vault Authentication

VSO authenticates to Vault using the Kubernetes auth method:

1. VSO reads the pod's service account JWT token.
2. VSO presents the JWT to Vault's Kubernetes auth backend (`kubernetes` mount).
3. Vault calls the EKS API server's TokenReview endpoint (using the `vault-auth` service account with `system:auth-delegator`).
4. Vault validates the token and maps it to the `demo-go-web-vso-csi` role.
5. Vault issues a short-lived Vault token (max TTL: 24 hours) scoped to the `apps-policy`.

Terraform itself authenticates to Vault using HCP Terraform workload identity (JWT/OIDC)
at run time. The workspace identity is exchanged for a short-lived Vault token through the
configured Vault run role (`TFC_VAULT_RUN_ROLE`), avoiding long-lived static Vault tokens.

---

## Design Decisions

| Decision | Rationale |
| --- | --- |
| Numbered file naming (`1_`, `2_`, `3_`) | Makes the deployment order explicit and self-documenting |
| `time_sleep` gates between steps | Ensures cluster readiness before Helm charts and Kubernetes resources are applied |
| CSI driver over VaultStaticSecret CRD | Demonstrates direct pod-level secret injection without creating Kubernetes Secret objects |
| KV v2 for secrets | Enables secret versioning, metadata, and rotation history |
| `pessimistic constraint operator (~>)` for providers | Allows patch-level provider upgrades without breaking the configuration |
| Workspace identity authentication | Uses JWT/OIDC workload identity for Vault and dynamic AWS credentials from HCP Terraform |
| 3 Elastic IPs for NLB | Required by AWS NLB with internet-facing scheme across 3 AZs |
| `sensitive = true` on `kubernetes_info` output | Prevents the kubeconfig update command from appearing in HCP Terraform plan logs |

---

## Provider Versions

| Provider | Version |
| --- | --- |
| `hashicorp/aws` | `6.37.0` |
| `hashicorp/vault` | `5.8.0` |
| `hashicorp/helm` | `3.1.1` |
| `hashicorp/kubernetes` | `3.0.1` |
| `hashicorp/random` | `3.8.1` |
| `hashicorp/time` | `0.13.1` |
| `hashicorp/tls` | `4.2.1` |
| `hashicorp/null` | `3.2.4` |

Terraform required version: `>= 1.5.0`

---

## CI/CD

| Workflow | Trigger | Purpose |
| --- | --- | --- |
| `terraform.yml` | Pull request | Runs `terraform fmt` and pushes formatting fixes back to the PR branch |
| `documentation.yml` | Pull request | Runs `terraform-docs` to regenerate `README.md` from header/footer templates |
| `linter.yml` | Pull request | Runs Super Linter (GitHub Actions, JSON, Markdown, TFLint, YAML) |
| `tag_release.yml` | Push / tag | Manages semantic version tagging and releases |

The `README.md` is auto-generated by `terraform-docs` using the config at `.github/terraform-docs/.tfdocs-config.yml`. Do not edit `README.md` directly.
