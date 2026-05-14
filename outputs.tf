# Copyright IBM Corp. 2024, 2026

locals {
  # only output the website address if all steps have been run
  website_output = var.step_2 && var.step_3 ? try("http://${aws_eip.nginx_ingress[0].public_ip}", "") : ""
}

output "website" {
  description = "Use this address to access the VSO demo"
  value       = local.website_output
}

output "vault_address" {
  description = "Use this address to login to the Vault UI"
  value       = var.ddr_vault_public_endpoint
}

output "vault_namespace" {
  description = "Switch to this namespace to locate the resources for this demo"
  value       = replace(vault_namespace.namespace.id, "admin/", "")
}

output "kubernetes_info" {
  description = "(Optional) Use this command to configure kubectl to access the EKS cluster"
  sensitive   = true
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}
