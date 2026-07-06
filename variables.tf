# Copyright IBM Corp. 2024, 2026

#------------------------------------------------------------------------------
# Required variables
#------------------------------------------------------------------------------

variable "doormat_username" {
  description = "(Optional) Doormat username used to construct the IAM developer role ARN for EKS cluster access and KMS key administration (e.g. firstname.lastname_company). Leave empty to skip adding the doormat role as a KMS key administrator and EKS access entry."
  type        = string
  default     = ""

  validation {
    condition     = var.doormat_username == "" || can(regex("^[a-zA-Z0-9._-]+$", var.doormat_username))
    error_message = "doormat_username must contain only letters, numbers, dots, underscores, or hyphens."
  }
}

variable "vault_address" {
  description = "(Required) Full URL of the HashiCorp Vault cluster (for example `https://vault.example.com:8200`). Used by the Vault provider and the Vault Secrets Operator Helm chart."
  type        = string

  validation {
    condition     = can(regex("^https?://", var.vault_address))
    error_message = "vault_address must be a valid URL starting with http:// or https://."
  }
}

#------------------------------------------------------------------------------
# Optional variables
#------------------------------------------------------------------------------

variable "customer_name" {
  description = "(Optional) Short name for the customer. Used to prefix and uniquely identify all provisioned resources. Must be lowercase letters, numbers, and hyphens only, 50 characters maximum."
  type        = string
  default     = ""

  validation {
    condition     = var.customer_name == "" || (length(var.customer_name) <= 50 && can(regex("^[a-z0-9-]*$", var.customer_name)))
    error_message = "customer_name must be 50 characters or less and can only contain lowercase letters, numbers, and hyphens."
  }
}

variable "instance_type" {
  description = "(Optional) EC2 instance type for the EKS managed node group."
  type        = string
  default     = "t3.medium"

  validation {
    condition = contains([
      "t3.medium",
      "t3.large",
      "t3.xlarge",
      "m6i.large",
      "m6i.xlarge",
      "m6a.large",
      "m6a.xlarge",
    ], var.instance_type)
    error_message = "instance_type must be one of: t3.medium, t3.large, t3.xlarge, m6i.large, m6i.xlarge, m6a.large, or m6a.xlarge."
  }
}

variable "region" {
  description = "(Optional) AWS region where all resources are provisioned."
  type        = string
  default     = "ca-central-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]+$", var.region))
    error_message = "region must be a valid AWS region identifier (e.g. ca-central-1, eu-central-1)."
  }
}

variable "static_app_rollout_token" {
  description = "(Optional) Change this value to force a rollout restart of the Step 3 demo deployment. Example: 2026-07-06T15:30:00Z"
  type        = string
  default     = ""
}

variable "step_2" {
  description = "(Optional) Set to true after Step 1 completes successfully. Deploys Kubernetes tooling: nginx ingress, Vault Secrets Operator, Vault Kubernetes auth backend, and RBAC resources."
  type        = bool
  default     = false
}

variable "step_3" {
  description = "(Optional) Set to true after Step 2 completes successfully. Deploys the CSISecrets custom resource and the demo Go web application. Requires step_2 = true."
  type        = bool
  default     = false
}

variable "uptycs_tags" {
  description = "(Optional) Comma-separated Uptycs tags in UPDATE/CCODE/UT/OWNER format."
  type        = string
  default     = "DEMO/CCODE/UT/SEC"
}
