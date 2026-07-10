# AWS EKS with Vault Secrets Operator + CSI Integration

## What this demo demonstrates

This demo provisions a production-oriented AWS environment to show how HashiCorp Vault secrets
can be delivered **directly into Kubernetes pods** via the Vault Secrets Operator (VSO) CSI
provider — without ever storing them as Kubernetes `Secret` objects.

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

## Secret Rotation

### What Happens When a Secret is Rotated

When the Vault secret at `webapp/app/config` is updated (e.g., `message` field changed), the following sequence occurs:

1. **Vault stores the new secret version.** KV v2 retains previous versions; the new version becomes the current default.
2. **VSO detects the change.** The VSO operator continuously reconciles `CSISecrets` resources and polls Vault for updates based on its refresh interval.
3. **VSO updates the CSI node staging.** The updated secret data is written to the ephemeral CSI staging area on the node.
4. **Running pods do NOT automatically pick up the change.** Because the secret is a CSI volume (not a projected volume), running pods continue to see the original data.
5. **After a pod restart, the new secret is visible.** When a pod is restarted (rolling update, node eviction, or manual deletion), the new CSI volume is mounted with the current Vault secret.

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

## How to Conduct the Demo

### Provisioning prerequisites

Before provisioning, configure the workspace with the required inputs:

1. Terraform variable `vault_address` (required).
2. Terraform variables `owner` and `repository` (optional, but highly recommended for resource tagging).
3. Terraform variable `doormat_username` (optional, but recommended to grant your AWS SSO role access to the EKS cluster).
4. HCP Terraform AWS Dynamic Provider Credentials enabled for the workspace (`TFC_AWS_PROVIDER_AUTH=true` and `TFC_AWS_RUN_ROLE_ARN` set).
5. HCP Terraform Vault provider authentication enabled with JWT/OIDC (`TFC_VAULT_PROVIDER_AUTH=true`).
6. Vault auth context variables set in the workspace (`TFC_VAULT_ADDR`, `TFC_VAULT_NAMESPACE`, `TFC_VAULT_RUN_ROLE`, and optional `TFC_VAULT_AUTH_PATH`).

After variables are configured, trigger runs from the workspace (VCS-driven) or via CLI-driven apply if your workflow uses local execution.

### Step 1 — Provision the infrastructure

1. Set `step_2 = false` and `step_3 = false` (default values).
2. Trigger Run #1.
3. Confirm the EKS cluster is healthy:
   - Open the **AWS Console → EKS → Clusters** and verify `<resources_prefix>-<random_id>-eks` (e.g. `vso-csi-a1b2-eks`) shows **Active** status.
4. Confirm the Vault secret was created:
   - Open the **Vault UI** using the `vault_address` output.
   - Switch to the namespace shown in the `vault_namespace` output.
   - Navigate to **Secrets → webapp → app/config** and verify the secret exists.

### Step 2 — Deploy Kubernetes tooling

1. Set `step_2 = true` in the workspace variables.
2. Trigger Run #2.
3. Confirm the VSO pod is running:
   - Open the **AWS Console → EKS → Clusters → <resources_prefix>-<random_id>-eks** (e.g. `vso-csi-a1b2-eks`).
   - Click the **Resources** tab → **Workloads → Pods**.
   - Filter by namespace `demo-go-web-vso-csi` and verify a `vault-secrets-operator-*` pod shows **Running** status.
4. Confirm the VSO CSI driver is registered:
   - In the same **Resources** tab, navigate to **Storage → CSI Drivers**.
   - Verify `csi.vso.hashicorp.com` appears in the list.

### Step 3 — Deploy the application

1. Set `step_3 = true` in the workspace variables.
2. Trigger Run #3.
3. Confirm all 3 replicas are ready:
   - Open the **AWS Console → EKS → Clusters → <resources_prefix>-<random_id>-eks**.
   - Click the **Resources** tab → **Workloads → Deployments**.
   - Filter by namespace `demo-go-web-vso-csi` and verify `demo-webapp` shows **3/3** pods ready.
4. Open the demo website using the `website` Terraform output (e.g. `https://<demo_subdomain>.<public_hosted_zone>`).
5. The page displays the `message` value stored in Vault (`webapp/app/config`).

### Important behavior

- The step variables are not auto-updated by Terraform.
- You must change `step_2` and `step_3` manually at the workspace level.
- The full demo requires three separate runs in sequence.

### Walkthrough: Explaining the Configuration

Once the application is running, here is how you can explain the integration flow to your audience:

1. **Vault Policy (`2_vault_policy.tf`)**:
   - **Where:** Vault UI → Policies → `apps-policy`.
   - **What to say:** Explain that this policy grants read-only access strictly to the `webapp/*` path where the application's secret resides.
2. **Kubernetes Auth Method (`2_vault_kube.tf`)**:
   - **Where:** Vault UI → Access → `kubernetes` → Roles → `demo-go-web-vso-csi`.
   - **What to say:** Explain how Vault is configured to trust the EKS cluster. Show the role that ties the `apps-policy` to the specific Kubernetes service account (`vault-auth`) and namespace (`demo-go-web-vso-csi`), enforcing strict identity mapping.
3. **Vault Secrets Operator Helm Chart (`2_kube_vso.tf`)**:
   - **Where:** Terraform codebase (`2_kube_vso.tf`).
   - **What to say:** Highlight the `values.yaml` configuration mapping where the CSI driver is enabled natively (`csi.enabled: true`).
4. **CSISecrets Custom Resource (`3_kube_static_app.tf`)**:
   - **Where:** AWS Console → EKS → Clusters → `<resources_prefix>-<random_id>-eks` → Resources → Custom Resources → `CSISecrets`.
   - **What to say:** Show the developer-facing Kubernetes manifest defining exactly which secret path to fetch, and which Kubernetes service account is authorized to consume it.
5. **Pod Volume Mount (`3_kube_static_app.tf`)**:
   - **Where:** AWS Console → EKS → Clusters → `<resources_prefix>-<random_id>-eks` → Resources → Workloads → Pods → Select a `demo-webapp` pod → YAML view.
   - **What to say:** Show the pod specification. Highlight how the pod utilizes the `csi.vso.hashicorp.com` storage driver via a `VolumeMount`, bypassing standard injected Kubernetes Secrets.
6. **No Kubernetes Secrets Generated**:
   - **Where:** AWS Console → EKS → Clusters → `<resources_prefix>-<random_id>-eks` → Resources → Configuration → Secrets.
   - **What to say:** Filter by the `demo-go-web-vso-csi` namespace. Prove to the audience that there are **no application secret objects** stored here. The only secrets present are standard Kubernetes service account tokens. The actual application secret remains entirely ephemeral.

### Secret Rotation Demo

This section walks through the deliberate secret rotation pattern that VSO + CSI enables.

#### Rotate the secret in Vault

1. Open the Vault UI using the `vault_address` output.
2. Switch to the namespace shown in the `vault_namespace` output.
3. Navigate to **Secrets > webapp > app/config** and click **Create new version**.
4. Change the `message` field to a new value (for example:
   `"Secret rotation in action — version 2!"`).
5. Save the new version.

#### Observe the behavior

1. Quickly reload the demo web application — the **original message is likely still displayed**. This is expected:
   the CSI volume is bound to the pod at startup and is not live-reloaded while the pod is running.
   Vault still holds the updated secret, but the running pod retains the prior version in its
   ephemeral volume.

#### Automated Pod Rotation

1. To remove the need for manual console access, this demo provisions a Kubernetes `CronJob` that executes a `kubectl rollout restart deployment/demo-webapp` every 3 minutes.
2. Wait for up to 3 minutes to allow the CronJob to trigger.
3. As the deployment rolls over and replacement pods start, the VSO CSI driver re-authenticates to Vault, reads
   the current secret version, and injects the new data into the pod's ephemeral volume.
4. Reload the demo web application — the **new message from Vault is now displayed**.

#### What this demonstrates

- The pod lifecycle controls the rotation window, giving operators a deliberate and auditable
  change boundary.
- No Kubernetes `Secret` objects are modified — the rotation is purely between Vault and the pod.
- Vault KV v2 retains the prior version; rolling back is as simple as re-pinning the secret
  version in the `CSISecrets` resource and restarting pods.

## Permissions

### AWS Permissions

To provision the AWS resources managed by this code, the IAM role or user running Terraform
needs the following permissions:

- `acm:RequestCertificate` / `acm:DeleteCertificate` / `acm:DescribeCertificate` / `acm:AddTagsToCertificate`
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
- `route53:ChangeResourceRecordSets` / `route53:GetChange` / `route53:ListHostedZones` / `route53:GetHostedZone`

### Vault Permissions

The Vault token or dynamic credential used by Terraform must have the following capabilities:

- Create and manage namespaces (`sys/namespaces/*`).
- Enable and configure secret engines (`sys/mounts/*`).
- Create and update KV v2 secrets (`<namespace>/webapp/*`).
- Enable and configure the Kubernetes auth backend (`sys/auth/*`, `auth/kubernetes/*`).
- Create and manage Vault policies (`sys/policies/acl/*`).

## Authentications

### AWS Authentication

#### HCP Terraform / Terraform Enterprise Dynamic Credentials (OIDC)

Use dynamic provider credentials via OpenID Connect (OIDC) for secure, short-lived credentials when running in HCP Terraform or Terraform Enterprise.

- **Using environment variables (HCP Terraform Workspace)**
  - `TFC_AWS_PROVIDER_AUTH=true`
  - `TFC_AWS_RUN_ROLE_ARN=<your_aws_iam_role_arn>`

Documentation:

- [Dynamic Provider Credentials in HCP Terraform](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws-configuration)

#### [Environment Variables](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#environment-variables)

Credentials can be provided by using the `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and optionally `AWS_SESSION_TOKEN` environment variables. The Region can be set using the `AWS_REGION` or `AWS_DEFAULT_REGION` environment variables.

For example:

```hcl
provider "aws" {}
```

```bash
$ export AWS_ACCESS_KEY_ID="anaccesskey"
$ export AWS_SECRET_ACCESS_KEY="asecretkey"
$ export AWS_REGION="us-west-2"
$ terraform plan
```

Documentation:

- [AWS Provider Authentication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication)

### Vault Authentication

#### Static Token

Use environment variables to authenticate with a static Vault token:

- `VAULT_ADDR`: Set to your HCP Vault Dedicated cluster address (e.g., `https://my-cluster.vault.hashicorp.cloud:8200`).
- `VAULT_TOKEN`: Set to a valid Vault token with the permissions listed above.
- `VAULT_NAMESPACE`: Set to the parent namespace (e.g., `admin`) if applicable.

#### HCP Terraform Dynamic Credentials (Recommended)

For enhanced security, use HCP Terraform's dynamic provider credentials to authenticate to Vault without storing static tokens.
This method uses workload identity (JWT/OIDC) to generate short-lived Vault tokens automatically.

- `TFC_VAULT_PROVIDER_AUTH`: Set to `true`.
- `TFC_VAULT_ADDR`: Set to your HCP Vault Dedicated cluster address.
- `TFC_VAULT_NAMESPACE`: Set to the parent namespace.
- `TFC_VAULT_RUN_ROLE`: Set to the JWT role name configured in Vault.

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
