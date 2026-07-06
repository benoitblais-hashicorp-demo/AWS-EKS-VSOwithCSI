# AWS EKS with Vault Secrets Operator + CSI Integration

## What this demo demonstrates

This demo provisions a production-oriented AWS environment to show how HashiCorp Vault secrets
can be delivered **directly into Kubernetes pods** via the Vault Secrets Operator (VSO) CSI
provider — without ever storing them as Kubernetes `Secret` objects.

The demo is structured as a three-step gated deployment. Each step builds on the previous one,
making it easy to walk through the architecture live or use it as a training environment.

- **Step 1:** AWS VPC, EKS cluster, Vault namespace, and a static KV v2 secret.
- **Step 2:** Vault Kubernetes auth, VSO Helm chart (CSI driver enabled), nginx ingress, and RBAC.
- **Step 3:** A `CSISecrets` custom resource and a Go web application that reads Vault secrets
  from a CSI-mounted volume at `/var/run/secrets/vault`.

## Features

- AWS VPC with private and public subnets across multiple Availability Zones.
- NAT-based outbound connectivity for EKS worker nodes in private subnets.
- EKS cluster (v1.34) with a managed node group and core addons (CoreDNS, kube-proxy, VPC CNI,
  EKS Pod Identity Agent).
- HashiCorp Vault Kubernetes auth backend wired to the EKS cluster using service account token review.
- Vault Secrets Operator (VSO) deployed via Helm with the CSI provider driver enabled.
- `CSISecrets` custom resource that maps a Vault KV v2 path to a CSI volume.
- Secrets delivered directly into pods as ephemeral file-system volume mounts — no Kubernetes
  `Secret` objects created, no environment variable exposure.
- Nginx ingress controller backed by an internet-facing AWS Network Load Balancer with pre-allocated
  Elastic IPs.
- Go web application (`demo-go-web`) that renders Vault secret content to illustrate live delivery.
- Secret rotation support: update the Vault secret and restart pods to pick up the new value.

## Demo Components

- **AWS networking:** VPC, private and public subnets, Internet Gateway, NAT Gateway.
- **Compute:** EKS cluster with a managed node group (t3.medium, 1–3 nodes).
- **Ingress:** nginx ingress controller, AWS NLB, 3 pre-allocated Elastic IPs.
- **Vault:** Namespace, KV v2 mount (`creds`), static secret (`creds/app/config`), Kubernetes
  auth backend, role, and policy.
- **VSO:** Helm release v1.3.0 with the CSI driver side-car enabled (`csi.enabled: true`).
- **Kubernetes workload:** `CSISecrets` CR, deployment (3 replicas), ClusterIP service, ingress rule.
- **RBAC:** `vault-auth` service account, long-lived token secret, `system:auth-delegator` cluster
  role binding.

## How this demo works

1. Terraform provisions the AWS VPC and the EKS cluster (Step 1).
2. Terraform creates a Vault namespace and a static KV v2 secret (`creds/app/config`) with a
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
3. Confirm the EKS cluster is healthy and the Vault secret exists at `creds/app/config`.
4. Confirm the Vault namespace output is available from the workspace outputs.

### Step 2 — Deploy Kubernetes tooling

1. Set `step_2 = true` in the workspace variables.
2. Trigger Run #2.
3. Confirm the VSO pod is running: `kubectl get pods -n simple-app`.
4. Verify the `csi.vso.hashicorp.com` driver is registered on the node:
   `kubectl get csidrivers`.

### Step 3 — Deploy the application

1. Set `step_3 = true` in the workspace variables.
2. Trigger Run #3.
3. Wait for the deployment to become healthy: `kubectl rollout status deployment/static-secrets -n simple-app`.
4. Open the demo website using the `website` Terraform output (`http://<elastic-ip>`).
5. The page displays the `message` value stored in Vault (`creds/app/config`).

### Important behavior

- The step variables are not auto-updated by Terraform.
- You must change `step_2` and `step_3` manually at the workspace level.
- The full demo requires three separate runs in sequence.

### Validate kubectl access

Use the `kubernetes_info` output to configure local `kubectl` access:

```bash
aws eks update-kubeconfig --name <cluster-name> --region <region>
```

## Secret Rotation Demo

This section walks through the deliberate secret rotation pattern that VSO + CSI enables.

### Rotate the secret in Vault

1. Open the Vault UI using the `vault_address` output.
2. Switch to the namespace shown in the `vault_namespace` output.
3. Navigate to **Secrets > creds > app/config** and click **Create new version**.
4. Change the `message` field to a new value (for example:
   `"Secret rotation in action — version 2!"`).
5. Save the new version.

### Observe the behavior

6. Reload the demo web application — the **original message is still displayed**. This is expected:
   the CSI volume is bound to the pod at startup and is not live-reloaded while the pod is running.
   Vault still holds the updated secret, but the running pod retains the prior version in its
   ephemeral volume.

### Apply the rotation to running pods

7. Trigger a rolling restart of the deployment:

   ```bash
   kubectl rollout restart deployment/static-secrets -n simple-app
   ```

8. As each pod is replaced, the VSO CSI driver re-authenticates to Vault, reads the current
   secret version, and injects the new data into the replacement pod's ephemeral volume.
9. Reload the demo web application — the **new message from Vault is now displayed**.

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
- Create and update KV v2 secrets (`<namespace>/creds/*`).
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
