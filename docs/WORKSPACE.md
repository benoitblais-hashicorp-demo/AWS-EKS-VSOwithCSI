# HCP Terraform Workspace Configuration

This document lists all variables required to configure the HCP Terraform workspace
before running this demo.

---

## Terraform Variables

Set these in the workspace under **Variables → Terraform variables**.

### Required

| Variable | Example value | Sensitive | Description |
| --- | --- | --- | --- |
| `vault_address` | `https://vault-cluster.example.com:8200` | No | Full URL of the HashiCorp Vault cluster used by the Vault provider and the Vault Secrets Operator Helm chart. |

### Optional

| Variable | Default | Sensitive | Description |
| --- | --- | --- | --- |
| `owner` | `"user@example.com"` | No | Owner identifier (e.g., email) used for AWS tagging. |
| `repository` | `"github.com/hashicorp/terraform-demo"` | No | URL of the repository where the codebase resides. |
| `customer_name` | `"hashicat"` | No | Short name for the customer. Used to prefix all provisioned resources. Lowercase letters, numbers, and hyphens only, 50 characters maximum. |
| `doormat_username` | `""` | No | Doormat username used to construct the IAM developer role ARN (`arn:aws:iam::<account_id>:role/aws_<doormat_username>-developer`). When set, adds the role as a KMS key administrator and EKS access entry. Leave empty to omit. |
| `instance_type` | `t3.medium` | No | EC2 instance type for the EKS managed node group. Allowed values: `t3.medium`, `t3.large`, `t3.xlarge`, `m6i.large`, `m6i.xlarge`, `m6a.large`, `m6a.xlarge`. |
| `region` | `ca-central-1` | No | AWS region where all resources are provisioned. |
| `step_2` | `false` | No | Set to `true` after Step 1 completes. Deploys Kubernetes tooling, Vault Secrets Operator, and Vault Kubernetes auth. |
| `step_3` | `false` | No | Set to `true` after Step 2 completes. Deploys the CSISecrets resource and the demo web application. |

---

## Environment Variables

Set these in the workspace under **Variables → Environment variables**.

| Variable | Example value | Sensitive | Description |
| --- | --- | --- | --- |
| `TFC_VAULT_PROVIDER_AUTH` | `true` | No | Enables HCP Terraform workload identity authentication for the Vault provider. |
| `TFC_VAULT_ADDR` | `https://vault-cluster.example.com:8200` | No | Vault cluster URL used by provider authentication. |
| `TFC_VAULT_NAMESPACE` | `admin` | No | Root Vault namespace. Required for HCP Vault Dedicated and Vault Enterprise. Omit for Vault Community Edition. |
| `TFC_VAULT_RUN_ROLE` | `tfc-demo-role` | No | Vault role bound to HCP Terraform workspace identity claims. |
| `TFC_VAULT_AUTH_PATH` | `jwt` | No | Vault auth mount path for JWT/OIDC login. Optional when using default path. |

### AWS Credentials

Use one of the two options below — do not configure both.

**Option A — HCP Terraform native OIDC (recommended):**
Configure the workspace under **Settings → Provider credentials → AWS** using an OIDC trust
relationship. No environment variables are needed for AWS authentication.

**Option B — Static credentials (fallback only):**

| Variable | Sensitive | Description |
| --- | --- | --- |
| `AWS_ACCESS_KEY_ID` | **Yes** | AWS access key ID for a user or assumed role with the required permissions. |
| `AWS_SECRET_ACCESS_KEY` | **Yes** | Corresponding AWS secret access key. |
| `AWS_SESSION_TOKEN` | **Yes** | Session token, required when using temporary credentials (STS / assumed role). |

---

## Deployment Sequence

Configure all **Required** variables and environment variables before the first apply.
Then follow the three-step sequence:

```text
Step 1  →  Apply with step_2 = false, step_3 = false  (default)
           Provisions: VPC, EKS cluster, Vault namespace, KV v2 secret

Step 2  →  Set step_2 = true, apply
           Provisions: nginx ingress, VSO Helm chart, Vault Kubernetes auth, RBAC

Step 3  →  Set step_3 = true, apply
           Provisions: CSISecrets CR, Go web application, ingress rule
```

After Step 3, the `website` output contains the public URL of the demo application.

---

## Required AWS Permissions

The IAM role or user running Terraform needs the following permissions:

### EC2 / VPC

- `ec2:Describe*`, `ec2:CreateVpc`, `ec2:DeleteVpc`, `ec2:CreateSubnet`, `ec2:DeleteSubnet`
- `ec2:CreateRouteTable`, `ec2:DeleteRouteTable`, `ec2:CreateRoute`, `ec2:DeleteRoute`
- `ec2:AssociateRouteTable`, `ec2:DisassociateRouteTable`
- `ec2:CreateInternetGateway`, `ec2:AttachInternetGateway`, `ec2:DeleteInternetGateway`
- `ec2:AllocateAddress`, `ec2:ReleaseAddress`, `ec2:CreateNatGateway`, `ec2:DeleteNatGateway`
- `ec2:CreateSecurityGroup`, `ec2:DeleteSecurityGroup`
- `ec2:AuthorizeSecurityGroupIngress`, `ec2:RevokeSecurityGroupIngress`
- `ec2:AuthorizeSecurityGroupEgress`, `ec2:RevokeSecurityGroupEgress`
- `ec2:CreateTags`, `ec2:DeleteTags`

### EKS

- `eks:CreateCluster`, `eks:DeleteCluster`, `eks:DescribeCluster`, `eks:UpdateClusterConfig`
- `eks:CreateNodegroup`, `eks:DeleteNodegroup`, `eks:DescribeNodegroup`
- `eks:CreateAddon`, `eks:DeleteAddon`, `eks:DescribeAddon`
- `eks:CreateAccessEntry`, `eks:DeleteAccessEntry`, `eks:AssociateAccessPolicy`
- `eks:TagResource`, `eks:UntagResource`

### IAM

- `iam:CreateRole`, `iam:DeleteRole`, `iam:GetRole`, `iam:PassRole`
- `iam:CreatePolicy`, `iam:DeletePolicy`, `iam:GetPolicy`, `iam:GetPolicyVersion`
- `iam:AttachRolePolicy`, `iam:DetachRolePolicy`
- `iam:CreateInstanceProfile`, `iam:DeleteInstanceProfile`, `iam:GetInstanceProfile`
- `iam:AddRoleToInstanceProfile`, `iam:RemoveRoleFromInstanceProfile`

### KMS

- `kms:CreateKey`, `kms:DescribeKey`, `kms:CreateAlias`, `kms:DeleteAlias`
- `kms:EnableKeyRotation`, `kms:GetKeyPolicy`, `kms:PutKeyPolicy`, `kms:ScheduleKeyDeletion`

---

## Required Vault Permissions

The Vault role referenced by `TFC_VAULT_RUN_ROLE` must grant capabilities such as:

```hcl
path "sys/namespaces/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "+/auth/kubernetes/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "+/webapp/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
```
