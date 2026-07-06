# Copyright IBM Corp. 2024, 2026

output "kubernetes_info" {
  description = "AWS CLI command to configure kubectl access to the EKS cluster"
  sensitive   = true
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}

output "vault_address" {
  description = "Vault UI address for this demo"
  value       = var.vault_address
}

output "vault_namespace" {
  description = "Vault namespace scoped to this demo deployment"
  value       = replace(vault_namespace.namespace.id, "admin/", "")
}

output "website" {
  description = "Public URL of the VSO + CSI demo web application (available after step_3 = true)"
  value       = var.step_2 && var.step_3 ? try("http://${aws_eip.nginx_ingress[0].public_ip}", "") : ""
}
