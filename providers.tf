# Copyright IBM Corp. 2024, 2026

provider "vault" {
  # Authentication is provided by HCP Terraform workload identity
  # when TFC_VAULT_PROVIDER_AUTH=true is set at the workspace level.
  # The address is automatically injected via the TFC_VAULT_ADDR environment variable.
}

provider "aws" {
  # shared_config_files = [var.tfc_aws_dynamic_credentials.default.shared_config_file]
  region = var.region
}

provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    command     = "aws"
  }
}
