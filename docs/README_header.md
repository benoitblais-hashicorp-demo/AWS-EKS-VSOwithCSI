# AWS EKS with Vault Secrets Operator + CSI Integration

## What this demo demonstrates

This demo provisions a production-oriented AWS environment to show how HashiCorp Vault secrets
can be delivered **directly into Kubernetes pods** via the Vault Secrets Operator (VSO) CSI
provider — without ever storing them as Kubernetes `Secret` objects.

## Demo Components

- **AWS Networking:** VPC with private/public subnets across multiple Availability Zones, Internet Gateway, and NAT-based outbound connectivity for EKS worker nodes.
- **Compute:** EKS cluster (v1.34) with a managed node group (t3.medium, 1–3 nodes) and core addons (CoreDNS, kube-proxy, VPC CNI, EKS Pod Identity Agent).
- **Ingress:** Nginx ingress controller backed by an internet-facing AWS Network Load Balancer (NLB) with 3 pre-allocated Elastic IPs.
- **Vault:** Isolated namespace, KV v2 mount (`webapp`), and static secret (`webapp/app/config`). Contains the Kubernetes auth backend wired to the EKS cluster using service account token review, plus required roles and policies.
- **Vault Secrets Operator (VSO):** Helm release v1.3.0 deployed with the CSI provider driver side-car enabled (`csi.enabled: true`).
- **Kubernetes Workload & RBAC:** Includes the Go web application deployment (`demo-webapp`, 3 replicas), ClusterIP service, and ingress rule. Configures a `vault-auth` service account, long-lived token secret, and `system:auth-delegator` cluster role binding.
- **CSISecrets Custom Resource:** Maps the Vault KV v2 path to a CSI volume, delivering secrets directly into pods as ephemeral file-system volume mounts at `/var/run/secrets/vault` — no Kubernetes `Secret` objects are created, preventing environment variable exposure. Supports deliberate secret rotation by picking up new values on pod restart.

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

## How this demo works

1. Terraform provisions the AWS VPC and the EKS cluster (Step 1).
2. Terraform creates a Vault namespace and a static KV v2 secret (`webapp/app/config`) with a
   `message` and `image_url` field (Step 1).
3. Terraform deploys the VSO Helm chart with the CSI driver enabled. The CSI driver registers
   the `csi.vso.hashicorp.com` storage driver on each node (Step 2).
4. Terraform configures the Vault Kubernetes auth backend, pointing it at the EKS cluster API
   server and the `vault-auth` service account for token review (Step 2).
5. Terraform creates the `CSISecrets` custom resource, which tells VSO which Vault path to expose
   and which namespace is authorised to consume it (Step 3).
6. Terraform deploys the Go web application. Each pod's spec references the CSI volume:
   the driver authenticates to Vault, retrieves the secret, and writes the data as files into
   the pod's ephemeral volume at `/var/run/secrets/vault` (Step 3).
7. The web application reads the secret files and renders the `message` field on the demo page.

## Demo Value Proposition

- Demonstrates **zero Kubernetes Secrets for application secrets**: the Vault secret never becomes
  a `Secret` object in the Kubernetes API server.
- Shows **Vault as the single source of truth**: secrets are read at pod startup from Vault,
  not from a cached copy.
- Illustrates **deliberate, auditable secret rotation**: when a Vault secret is updated, running
  pods continue to use the prior version until they are restarted — giving operators full control
  over the rotation window.
- Provides a **reusable baseline** for enterprise patterns: dynamic Vault credentials, KV v2
  versioning, least-privilege Vault policies, and private EKS node placement.


## Secret Rotation

### What Happens When a Secret is Rotated

When the Vault secret at `webapp/app/config` is updated (e.g., `message` field changed), the following sequence occurs:

1. **Vault stores the new secret version.** KV v2 retains previous versions; the new version becomes the current default.
2. **VSO detects the change.** The VSO operator continuously reconciles `CSISecrets` resources and polls Vault for updates based on its refresh interval.
3. **VSO updates the CSI node staging.** The updated secret data is written to the ephemeral CSI staging area on the node.
4. **Running pods do NOT automatically pick up the change.** Because the secret is a CSI volume (not a projected volume), running pods continue to see the original data.
5. **After a pod restart, the new secret is visible.** When a pod is restarted (rolling update, node eviction, or manual deletion), the new CSI volume is mounted with the current Vault secret.

## How to Conduct the Demo

### Provisioning prerequisites

Before provisioning, configure the workspace with the required inputs:

1. Terraform variable `doormat_username` (required).
2. Terraform variable `vault_address` (required).
3. HCP Terraform AWS Dynamic Provider Credentials enabled for the workspace (OIDC role assumption).
4. HCP Terraform Vault provider authentication enabled with JWT/OIDC (`TFC_VAULT_PROVIDER_AUTH=true`).
5. Vault auth context variables set in the workspace (`TFC_VAULT_ADDR`, `TFC_VAULT_NAMESPACE`, `TFC_VAULT_RUN_ROLE`, and optional `TFC_VAULT_AUTH_PATH`).

After variables are configured, trigger runs from the workspace (VCS-driven) or via CLI-driven apply if your workflow uses local execution.

### Step 1 — Provision the infrastructure

1. Set `step_2 = false` and `step_3 = false` (default values).
2. Trigger Run #1.
3. Confirm the EKS cluster is healthy:
   - Open the **AWS Console → EKS → Clusters** and verify `hashicat-inc-ynfyas-eks` shows **Active** status.
4. Confirm the Vault secret was created:
   - Open the **Vault UI** using the `vault_address` output.
   - Switch to the namespace shown in the `vault_namespace` output.
   - Navigate to **Secrets → webapp → app/config** and verify the secret exists.

### Step 2 — Deploy Kubernetes tooling

1. Set `step_2 = true` in the workspace variables.
2. Trigger Run #2.
3. Confirm the VSO pod is running:
   - Open the **AWS Console → EKS → Clusters → hashicat-inc-ynfyas-eks**.
   - Click the **Resources** tab → **Workloads → Pods**.
   - Filter by namespace `demo-go-web-vso-csi` and verify a `vault-secrets-operator-*` pod shows **Running** status.
4. Confirm the VSO CSI driver is registered:
   - In the same **Resources** tab, navigate to **Storage → CSI Drivers**.
   - Verify `csi.vso.hashicorp.com` appears in the list.

### Step 3 — Deploy the application

1. Set `step_3 = true` in the workspace variables.
2. Trigger Run #3.
3. Confirm all 3 replicas are ready:
   - Open the **AWS Console → EKS → Clusters → hashicat-inc-ynfyas-eks**.
   - Click the **Resources** tab → **Workloads → Deployments**.
   - Filter by namespace `demo-go-web-vso-csi` and verify `demo-webapp` shows **3/3** pods ready.
4. Open the demo website using the `website` Terraform output (`http://<elastic-ip>`).
5. The page displays the `message` value stored in Vault (`webapp/app/config`).

### Important behavior

- The step variables are not auto-updated by Terraform.
- You must change `step_2` and `step_3` manually at the workspace level.
- The full demo requires three separate runs in sequence.

### Walkthrough: Explaining the Configuration

Once the application is running, it is helpful to explain how the configuration pieces fit together to enable the CSI integration:

1. **Vault Policy (`2_vault_policy.tf`)**:
   Show the `apps-policy` in Vault. Explain that this policy grants read-only access strictly to the `webapp/*` path where the application's secret resides.
2. **Kubernetes Auth Method (`2_vault_kube.tf`)**:
   Explain how Vault is configured to trust the EKS cluster. Show the `demo-go-web-vso-csi` role in Vault, which ties the `apps-policy` to the specific Kubernetes service account (`vault-auth`) and namespace (`demo-go-web-vso-csi`), enforcing strict identity mapping.
3. **Vault Secrets Operator Helm Chart (`2_kube_vso.tf`)**:
   Highlight the `values.yaml` configuration where the CSI driver is enabled (`csi.enabled: true`) and default Vault connection methods are disabled to enforce explicit authorization via Custom Resources.
4. **CSISecrets Custom Resource (`3_kube_static_app.tf`)**:
   Show the developer-facing Kubernetes manifest. Explain how it connects the application to Vault:
   - Points to the Vault connection and auth method (`vaultAuthRef`).
   - Specifies the exact secret path to fetch (`vaultStaticSecrets`).
   - Restricts which pods can mount this secret (`accessControl` with `serviceAccountPattern` and `namespacePatterns`).
5. **Pod Volume Mount (`3_kube_static_app.tf`)**:
   Show the deployment specification. The pod utilizes the `csi.vso.hashicorp.com` storage driver for its volume and passes the `csiSecretsName` attribute. This is how Kubernetes natively mounts the ephemeral secret file into the pod without ever creating a traditional Kubernetes `Secret` object.

## Secret Rotation Demo

This section walks through the deliberate secret rotation pattern that VSO + CSI enables.

### Rotate the secret in Vault

1. Open the Vault UI using the `vault_address` output.
2. Switch to the namespace shown in the `vault_namespace` output.
3. Navigate to **Secrets > webapp > app/config** and click **Create new version**.
4. Change the `message` field to a new value (for example:
   `"Secret rotation in action — version 2!"`).
5. Save the new version.

### Observe the behavior

1. Reload the demo web application — the **original message is still displayed**. This is expected:
   the CSI volume is bound to the pod at startup and is not live-reloaded while the pod is running.
   Vault still holds the updated secret, but the running pod retains the prior version in its
   ephemeral volume.

### Apply the rotation to running pods

1. In the **AWS Console → EKS → Clusters → hashicat-inc-ynfyas-eks**, go to the
   **Resources** tab → **Workloads → Pods**, filter by namespace `demo-go-web-vso-csi`.
2. Select all `demo-webapp-*` pods and delete them (one at a time or all at once).
   The deployment controller will immediately schedule replacement pods.
3. As each replacement pod starts, the VSO CSI driver re-authenticates to Vault, reads
   the current secret version, and injects the new data into the pod's ephemeral volume.
4. Reload the demo web application — the **new message from Vault is now displayed**.

### What this demonstrates

- The pod lifecycle controls the rotation window, giving operators a deliberate and auditable
  change boundary.
- No Kubernetes `Secret` objects are modified — the rotation is purely between Vault and the pod.
- Vault KV v2 retains the prior version; rolling back is as simple as re-pinning the secret
  version in the `CSISecrets` resource and restarting pods.

## Expected Behavior

- Step 1 provisions the EKS cluster, VPC, and the initial Vault secret.
- Step 2 deploys VSO and registers the CSI driver on all EKS worker nodes.
- Step 3 deploys the web application; the demo page loads and displays the Vault secret content.
- No `Secret` object of type `Opaque` (or any other type) is created to hold the application secret.
- Updating the Vault secret does not immediately affect running pods; a pod restart is required.
- The `website` output is only populated once both `step_2` and `step_3` are `true`.

## Permissions

### AWS Permissions

To provision the AWS resources managed by this code, the IAM role or user running Terraform
needs the following permissions:

- `ec2:DescribeAvailabilityZones`
- `ec2:DescribeImages`
- `ec2:DescribeVpcs`
- `ec2:CreateVpc` / `ec2:DeleteVpc`
- `ec2:CreateSubnet` / `ec2:DeleteSubnet`
- `ec2:CreateRouteTable` / `ec2:DeleteRouteTable`
- `ec2:CreateRoute` / `ec2:DeleteRoute`
- `ec2:AssociateRouteTable` / `ec2:DisassociateRouteTable`
- `ec2:CreateInternetGateway` / `ec2:AttachInternetGateway` / `ec2:DeleteInternetGateway`
- `ec2:AllocateAddress` / `ec2:ReleaseAddress`
- `ec2:CreateNatGateway` / `ec2:DeleteNatGateway`
- `ec2:CreateSecurityGroup` / `ec2:DeleteSecurityGroup`
- `ec2:AuthorizeSecurityGroupIngress` / `ec2:RevokeSecurityGroupIngress`
- `ec2:AuthorizeSecurityGroupEgress` / `ec2:RevokeSecurityGroupEgress`
- `ec2:CreateTags` / `ec2:DeleteTags`
- `ec2:DescribeInstances` / `ec2:DescribeInstanceTypes`
- `ec2:DescribeNetworkInterfaces`
- `eks:CreateCluster` / `eks:DeleteCluster` / `eks:DescribeCluster`
- `eks:CreateNodegroup` / `eks:DeleteNodegroup` / `eks:DescribeNodegroup`
- `eks:CreateAddon` / `eks:DeleteAddon` / `eks:DescribeAddon`
- `eks:CreateAccessEntry` / `eks:DeleteAccessEntry` / `eks:AssociateAccessPolicy`
- `eks:TagResource` / `eks:UntagResource`
- `iam:CreateRole` / `iam:DeleteRole` / `iam:GetRole` / `iam:PassRole`
- `iam:CreatePolicy` / `iam:DeletePolicy` / `iam:GetPolicy` / `iam:GetPolicyVersion`
- `iam:AttachRolePolicy` / `iam:DetachRolePolicy`
- `iam:CreateInstanceProfile` / `iam:DeleteInstanceProfile` / `iam:GetInstanceProfile`
- `iam:AddRoleToInstanceProfile` / `iam:RemoveRoleFromInstanceProfile`
- `kms:CreateKey` / `kms:DescribeKey` / `kms:CreateAlias` / `kms:DeleteAlias`
- `kms:EnableKeyRotation` / `kms:GetKeyPolicy` / `kms:PutKeyPolicy`
- `kms:ScheduleKeyDeletion`

### Vault Permissions

The Vault token or dynamic credential used by Terraform must have the following capabilities:

- Create and manage namespaces (`sys/namespaces/*`).
- Enable and configure secret engines (`sys/mounts/*`).
- Create and update KV v2 secrets (`<namespace>/webapp/*`).
- Enable and configure the Kubernetes auth backend (`sys/auth/*`, `auth/kubernetes/*`).
- Create and manage Vault policies (`sys/policies/acl/*`).

### HCP Terraform Permissions

To manage workspace variables and trigger runs, provide a user or team token with **Manage
workspaces** and **Read variables** permissions for the target workspace.

## Authentications

### AWS Authentication

AWS authentication uses HCP Terraform Dynamic Provider Credentials (OIDC role assumption).

- Configure the HCP Terraform workspace to assume an AWS IAM role via OIDC.
- Do not use long-lived static AWS credentials for normal runs.
- The `shared_config_file` variable in `variables_providers.tf` is pre-wired and can be
  uncommented in `providers.tf` once dynamic credentials are available in the workspace.

### Vault Authentication

Vault authentication uses HCP Terraform workload identity (JWT/OIDC) for the Vault provider.
The workspace exchanges a short-lived identity token with Vault at run time and receives a
scoped Vault token for the configured run role. This avoids long-lived `VAULT_TOKEN` secrets.

```hcl
provider "vault" {
  # Authentication is injected by HCP Terraform when
  # TFC_VAULT_PROVIDER_AUTH=true is configured in the workspace.
}
```

Recommended workspace environment variables for Vault JWT auth:

- `TFC_VAULT_PROVIDER_AUTH=true`
- `TFC_VAULT_ADDR=<vault_url>`
- `TFC_VAULT_NAMESPACE=<namespace>` (for HCP Vault Dedicated / Vault Enterprise)
- `TFC_VAULT_RUN_ROLE=<vault_role_name>`
- `TFC_VAULT_AUTH_PATH=<auth_mount_path>` (optional; defaults to `jwt`)

Do not set `VAULT_TOKEN` when using this model.

### HCP Terraform Authentication

The workspace is driven by a VCS connection. No manual `terraform init` or `terraform apply`
is required. Workspace variables are used for all provider credentials.

## Setup & Deployment

1. Set up an HCP Terraform Workspace connected to your VCS repository.
2. Configure the required workspace variables and HCP Terraform dynamic credentials (for AWS and Vault).
3. **Step 1:** Queue a run with `step_2 = false` and `step_3 = false`. This provisions the foundational AWS infrastructure and the Vault namespace.
4. **Step 2:** Update your workspace variables to set `step_2 = true`. To prevent parallel dependency failures, apply this step on its own to deploy the Kubernetes tooling (Nginx ingress, Uptycs EDR, VSO Helm Chart, Vault Auth).
5. **Step 3:** Finally, set `step_3 = true` and queue the final run. This deploys the CSISecrets resource and the target application pods.

## Troubleshooting & Known Issues

- **Vault Enterprise Validation Errors:** The VSO CSI driver requires Vault Enterprise to function and hard-validates this requirement by querying the `/sys/license/status` endpoint. If your pod's Vault policy does not grant `read` capability to this endpoint, the volume mount will throw a `vault enterprise client validation failed` error, completely blocking Pod scheduling.
- **Vault 403 Permission Denied during Token Review:** When mapping the Vault Kubernetes Auth backend inside an HCP Vault dedicated namespace, ensure that the `VaultAuth` custom resource refers to the Vault namespace using the **Namespace ID** instead of the FQDN path. Using the full namespace path generates a 403 error due to token evaluation logic.
