<!-- BEGIN_TF_DOCS -->
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
3. Confirm the EKS cluster is healthy:
   - Open the **AWS Console → EKS → Clusters** and verify `hashicat-inc-ynfyas-eks` shows **Active** status.
4. Confirm the Vault secret was created:
   - Open the **Vault UI** using the `vault_address` output.
   - Switch to the namespace shown in the `vault_namespace` output.
   - Navigate to **Secrets → creds → app/config** and verify the secret exists.

### Step 2 — Deploy Kubernetes tooling

1. Set `step_2 = true` in the workspace variables.
2. Trigger Run #2.
3. Confirm the VSO pod is running:
   - Open the **AWS Console → EKS → Clusters → hashicat-inc-ynfyas-eks**.
   - Click the **Resources** tab → **Workloads → Pods**.
   - Filter by namespace `simple-app` and verify a `vault-secrets-operator-*` pod shows **Running** status.
4. Confirm the VSO CSI driver is registered:
   - In the same **Resources** tab, navigate to **Storage → CSI Drivers**.
   - Verify `csi.vso.hashicorp.com` appears in the list.

### Step 3 — Deploy the application

1. Set `step_3 = true` in the workspace variables.
2. Trigger Run #3.
3. Confirm all 3 replicas are ready:
   - Open the **AWS Console → EKS → Clusters → hashicat-inc-ynfyas-eks**.
   - Click the **Resources** tab → **Workloads → Deployments**.
   - Filter by namespace `simple-app` and verify `static-secrets` shows **3/3** pods ready.
4. Open the demo website using the `website` Terraform output (`http://<elastic-ip>`).
5. The page displays the `message` value stored in Vault (`creds/app/config`).

### Important behavior

- The step variables are not auto-updated by Terraform.
- You must change `step_2` and `step_3` manually at the workspace level.
- The full demo requires three separate runs in sequence.

### Walkthrough: Explaining the Configuration

Once the application is running, it is helpful to explain how the configuration pieces fit together to enable the CSI integration:

1. **Vault Policy (`2_vault_policy.tf`)**:
   Show the `apps-policy` in Vault. Explain that this policy grants read-only access strictly to the `creds/*` path where the application's secret resides.
2. **Kubernetes Auth Method (`2_vault_kube.tf`)**:
   Explain how Vault is configured to trust the EKS cluster. Show the `simple-app` role in Vault, which ties the `apps-policy` to the specific Kubernetes service account (`vault-auth`) and namespace (`simple-app`), enforcing strict identity mapping.
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
3. Navigate to **Secrets > creds > app/config** and click **Create new version**.
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
   **Resources** tab → **Workloads → Pods**, filter by namespace `simple-app`.
2. Select all `static-secrets-*` pods and delete them (one at a time or all at once).
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

## Setup & Deployment

1. Set up an HCP Terraform Workspace connected to your VCS repository.
2. Configure the required workspace variables and HCP Terraform dynamic credentials (for AWS and Vault) as described in `docs/WORKSPACE.md`.
3. **Step 1:** Queue a run with `step_2 = false` and `step_3 = false`. This provisions the foundational AWS infrastructure and the Vault namespace.
4. **Step 2:** Update your workspace variables to set `step_2 = true`. To prevent parallel dependency failures, apply this step on its own to deploy the Kubernetes tooling (Nginx ingress, Uptycs EDR, VSO Helm Chart, Vault Auth).
5. **Step 3:** Finally, set `step_3 = true` and queue the final run. This deploys the CSISecrets resource and the target application pods.

## Troubleshooting & Known Issues

- **Vault Enterprise Validation Errors:** The VSO CSI driver requires Vault Enterprise to function and hard-validates this requirement by querying the `/sys/license/status` endpoint. If your pod's Vault policy does not grant `read` capability to this endpoint, the volume mount will throw a `vault enterprise client validation failed` error, completely blocking Pod scheduling.
- **Vault 403 Permission Denied during Token Review:** When mapping the Vault Kubernetes Auth backend inside an HCP Vault dedicated namespace, ensure that the `VaultAuth` custom resource refers to the Vault namespace using the **Namespace ID** instead of the FQDN path. Using the full namespace path generates a 403 error due to token evaluation logic.

## Documentation

## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.5.0)

- <a name="requirement_aws"></a> [aws](#requirement\_aws) (6.37.0)

- <a name="requirement_helm"></a> [helm](#requirement\_helm) (3.1.1)

- <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) (3.0.1)

- <a name="requirement_random"></a> [random](#requirement\_random) (3.8.1)

- <a name="requirement_time"></a> [time](#requirement\_time) (0.13.1)

- <a name="requirement_vault"></a> [vault](#requirement\_vault) (5.8.0)

## Modules

The following Modules are called:

### <a name="module_eks"></a> [eks](#module\_eks)

Source: terraform-aws-modules/eks/aws

Version: 21.15.1

### <a name="module_vpc"></a> [vpc](#module\_vpc)

Source: terraform-aws-modules/vpc/aws

Version: 6.6.0

## Required Inputs

The following input variables are required:

### <a name="input_vault_address"></a> [vault\_address](#input\_vault\_address)

Description: (Required) Full URL of the HashiCorp Vault cluster (for example `https://vault.example.com:8200`). Used by the Vault provider and the Vault Secrets Operator Helm chart.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_customer_name"></a> [customer\_name](#input\_customer\_name)

Description: (Optional) Short name for the customer. Used to prefix and uniquely identify all provisioned resources. Must be lowercase letters, numbers, and hyphens only, 50 characters maximum.

Type: `string`

Default: `""`

### <a name="input_demo_subdomain"></a> [demo\_subdomain](#input\_demo\_subdomain)

Description: (Optional) The subdomain to prepend to the public\_hosted\_zone for the application (e.g., 'vso-demo').

Type: `string`

Default: `"vsocsi-demo"`

### <a name="input_doormat_username"></a> [doormat\_username](#input\_doormat\_username)

Description: (Optional) Doormat username used to construct the IAM developer role ARN for EKS cluster access and KMS key administration (e.g. firstname.lastname\_company). Leave empty to skip adding the doormat role as a KMS key administrator and EKS access entry.

Type: `string`

Default: `""`

### <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type)

Description: (Optional) EC2 instance type for the EKS managed node group.

Type: `string`

Default: `"t3.medium"`

### <a name="input_public_hosted_zone"></a> [public\_hosted\_zone](#input\_public\_hosted\_zone)

Description: (Optional) The Route 53 public hosted zone name (e.g., 'example.com') where DNS validation and A records will be published. If set, an ACM certificate will be provisioned directly on the NGINX Network Load Balancer.

Type: `string`

Default: `"benoit-blais.sbx.hashidemos.io"`

### <a name="input_region"></a> [region](#input\_region)

Description: (Optional) AWS region where all resources are provisioned.

Type: `string`

Default: `"ca-central-1"`

### <a name="input_static_app_rollout_token"></a> [static\_app\_rollout\_token](#input\_static\_app\_rollout\_token)

Description: (Optional) Change this value to force a rollout restart of the Step 3 demo deployment. Example: 2026-07-06T15:30:00Z

Type: `string`

Default: `""`

### <a name="input_step_2"></a> [step\_2](#input\_step\_2)

Description: (Optional) Set to true after Step 1 completes successfully. Deploys Kubernetes tooling: nginx ingress, Vault Secrets Operator, Vault Kubernetes auth backend, and RBAC resources.

Type: `bool`

Default: `false`

### <a name="input_step_3"></a> [step\_3](#input\_step\_3)

Description: (Optional) Set to true after Step 2 completes successfully. Deploys the CSISecrets custom resource and the demo Go web application. Requires step\_2 = true.

Type: `bool`

Default: `false`

### <a name="input_uptycs_tags"></a> [uptycs\_tags](#input\_uptycs\_tags)

Description: (Optional) Comma-separated Uptycs tags in UPDATE/CCODE/UT/OWNER format.

Type: `string`

Default: `"UPDATE/PROD,CCODE/HashiCorp,UT/20A7V,OWNER/owner-email@hashicorp.com"`

## Resources

The following resources are used by this module:

- [aws_acm_certificate.public](https://registry.terraform.io/providers/hashicorp/aws/6.37.0/docs/resources/acm_certificate) (resource)
- [aws_acm_certificate_validation.public](https://registry.terraform.io/providers/hashicorp/aws/6.37.0/docs/resources/acm_certificate_validation) (resource)
- [aws_eip.nginx_ingress](https://registry.terraform.io/providers/hashicorp/aws/6.37.0/docs/resources/eip) (resource)
- [aws_route53_record.public_validation](https://registry.terraform.io/providers/hashicorp/aws/6.37.0/docs/resources/route53_record) (resource)
- [aws_route53_record.web_dns_record](https://registry.terraform.io/providers/hashicorp/aws/6.37.0/docs/resources/route53_record) (resource)
- [helm_release.nginx_ingress](https://registry.terraform.io/providers/hashicorp/helm/3.1.1/docs/resources/release) (resource)
- [helm_release.uptycs_edr](https://registry.terraform.io/providers/hashicorp/helm/3.1.1/docs/resources/release) (resource)
- [helm_release.vault_secrets_operator](https://registry.terraform.io/providers/hashicorp/helm/3.1.1/docs/resources/release) (resource)
- [kubernetes_cluster_role_binding_v1.vault](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/cluster_role_binding_v1) (resource)
- [kubernetes_deployment_v1.static_app](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/deployment_v1) (resource)
- [kubernetes_ingress_v1.apps](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/ingress_v1) (resource)
- [kubernetes_manifest.vault_auth](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/manifest) (resource)
- [kubernetes_manifest.vault_connection](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/manifest) (resource)
- [kubernetes_manifest.vault_csi_secret](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/manifest) (resource)
- [kubernetes_namespace_v1.edr](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/namespace_v1) (resource)
- [kubernetes_namespace_v1.ingress_nginx](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/namespace_v1) (resource)
- [kubernetes_namespace_v1.simple_app](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/namespace_v1) (resource)
- [kubernetes_secret_v1.vault_token](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/secret_v1) (resource)
- [kubernetes_service_account_v1.vault](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/service_account_v1) (resource)
- [kubernetes_service_v1.static_app](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/service_v1) (resource)
- [random_string.identifier](https://registry.terraform.io/providers/hashicorp/random/3.8.1/docs/resources/string) (resource)
- [time_sleep.eip_wait](https://registry.terraform.io/providers/hashicorp/time/0.13.1/docs/resources/sleep) (resource)
- [time_sleep.step_2](https://registry.terraform.io/providers/hashicorp/time/0.13.1/docs/resources/sleep) (resource)
- [time_sleep.step_3](https://registry.terraform.io/providers/hashicorp/time/0.13.1/docs/resources/sleep) (resource)
- [vault_auth_backend.kube_auth](https://registry.terraform.io/providers/hashicorp/vault/5.8.0/docs/resources/auth_backend) (resource)
- [vault_generic_secret.credentials](https://registry.terraform.io/providers/hashicorp/vault/5.8.0/docs/resources/generic_secret) (resource)
- [vault_kubernetes_auth_backend_config.kube_auth_cfg](https://registry.terraform.io/providers/hashicorp/vault/5.8.0/docs/resources/kubernetes_auth_backend_config) (resource)
- [vault_kubernetes_auth_backend_role.simple_app_role](https://registry.terraform.io/providers/hashicorp/vault/5.8.0/docs/resources/kubernetes_auth_backend_role) (resource)
- [vault_mount.credentials](https://registry.terraform.io/providers/hashicorp/vault/5.8.0/docs/resources/mount) (resource)
- [vault_namespace.namespace](https://registry.terraform.io/providers/hashicorp/vault/5.8.0/docs/resources/namespace) (resource)
- [vault_policy.apps_policy](https://registry.terraform.io/providers/hashicorp/vault/5.8.0/docs/resources/policy) (resource)
- [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/6.37.0/docs/data-sources/availability_zones) (data source)
- [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/6.37.0/docs/data-sources/caller_identity) (data source)
- [aws_ec2_instance_type_offerings.supported](https://registry.terraform.io/providers/hashicorp/aws/6.37.0/docs/data-sources/ec2_instance_type_offerings) (data source)
- [aws_iam_session_context.current](https://registry.terraform.io/providers/hashicorp/aws/6.37.0/docs/data-sources/iam_session_context) (data source)
- [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/6.37.0/docs/data-sources/partition) (data source)
- [aws_route53_zone.demo](https://registry.terraform.io/providers/hashicorp/aws/6.37.0/docs/data-sources/route53_zone) (data source)

## Outputs

The following outputs are exported:

### <a name="output_kubernetes_info"></a> [kubernetes\_info](#output\_kubernetes\_info)

Description: AWS CLI command to configure kubectl access to the EKS cluster

### <a name="output_vault_address"></a> [vault\_address](#output\_vault\_address)

Description: Vault UI address for this demo

### <a name="output_vault_namespace"></a> [vault\_namespace](#output\_vault\_namespace)

Description: Vault namespace scoped to this demo deployment

### <a name="output_website"></a> [website](#output\_website)

Description: Public URL of the VSO + CSI demo web application (available after step\_3 = true)

<!-- markdownlint-enable -->
## External Documentation
<!-- END_TF_DOCS -->