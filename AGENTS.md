# AGENTS.md for Terraform Project

This file provides instructions for AI coding agents working on this Terraform Project.

## Project Overview

This project provisions an AWS Elastic Kubernetes Service (EKS) cluster integrated with Vault Secrets Operator (VSO) and the Secrets Store CSI driver using Terraform.

## Module and Repository Structure

Organize your Terraform project as follows:

```text
├── .gitignore
├── LICENSE
├── README.md
├── main.tf
├── outputs.tf
├── providers.tf
├── variables.tf
├── versions.tf
├── docs/
│   ├── CODE_OF_CONDUCT.md
│   ├── CONTRIBUTING.md
│   ├── PULL_REQUEST_TEMPLATE.md
│   ├── README_footer.md
│   ├── README_header.md
│   ├── SECURITY.md
```

### Required Files and Directories

- `README.md` – Required in the root module. Generated automatically (e.g., via Terraform-Docs). Do not edit manually.
- `docs/README_header.md` - Describe the purpose of the code and provide required context.
- `docs/README_footer.md` - Provide links to external documentation used to generate the code.
- `main.tf` – Primary resource and data source definitions.
- `outputs.tf` – Output value definitions (alphabetical order).
- `providers.tf` – Provider configurations.
- `variables.tf` – Input variable definitions (alphabetical order with required variables at the top).
- `versions.tf` - Terraform version and provider requirements.

## Tools and Frameworks

- AI Agents should format their generated HCL optimally as local `terraform fmt`, `terraform init`, and `terraform validate` cannot be run directly during the session due to the VCS-driven workflow.
- Formatting and CI/CD validation are handled by an automated VCS workflow, meaning the Agent does not need to run a local linter or validation operations locally. Do your best to output valid HCL code and do not try to run Terraform commands in the terminal.
- Use `terraform-docs` to generate the `README.md` file using the header and footer (you don't need to do this manually if the CI does it, but you must create the header/footer files).

## README_header.md

When editing or creating `docs/README_header.md`, ensure it contains:
- A description of the general purpose of the code.
- A `Permissions` section containing the permissions required to provision resources for each provider.
- An `Authentications` section containing the authentication details required for each provider.
- A `Features` section containing key features managed by the code.

## README_footer.md

When editing or creating `docs/README_footer.md`, ensure it contains:
- An `External Documentation` section providing links to relevant external documentation used to develop the code (e.g., AWS, Kubernetes, Helm, and Vault Provider docs, HashiCorp learn guides for VSO and CSI).

## Code Guidelines

Refer to CONTRIBUTING.md for general coding guidelines. HashiCorp's Terraform style guide should be applied for all code generated.

## Resource Naming

- Use descriptive nouns separated by underscores.
- Do not include the resource type in the resource name.
- Wrap resource type and name in double quotes.
- Example: `resource "aws_eks_cluster" "main"` not `resource "aws_eks_cluster" "eks_main"`.

## Version Management

- Prefer the pessimistic constraint operator (`~>`) for modules and providers to allow safe updates within a compatible version range.
- Avoid using only the equals (`=`) operator unless you must lock to a single version for reproducibility or known issues.
- Pin the Terraform version using `required_version` in the `terraform` block.

## Provider Configuration

- Always include a default provider configuration.
- Define all providers in the same file (`providers.tf`).
- Define the default provider first, then aliased providers.
- Use `alias` as the first parameter in non-default provider blocks.

## Security and Secrets

- Never commit `.terraform` directories or local state files.
- The project leverages dynamic provider credentials natively supported by Terraform Cloud / Enterprise workspaces or the VCS workflow.
- Access secrets securely via workspace variables.
- Set `sensitive = true` for sensitive variables across all definitions.

## State Management

- State storage is managed natively by HCP Terraform workspaces. Data sharing between configurations relies on standard data sources or `tfe_outputs` where cross-workspace values are required.
