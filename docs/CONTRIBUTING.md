# Contributing

Thank you for your interest in contributing! This repository uses **Terraform** to manage Azure Management Groups. Please review these guidelines before contributing.

## Architecture Paradigm: HCP Terraform Workspaces

This project leverages standard Terraform configurations and uses HCP Terraform workspaces for remote execution and state management.

* **No Local State or CLI Applies:** Do not run `terraform apply` locally. All pushes to the main branch are evaluated and deployed by HCP Terraform natively via a VCS-driven workflow.
* **State Management:** Data sharing between distinct configurations relies on standard data sources or `tfe_outputs` where cross-workspace values are required.
* **Dynamic Credentials:** The project leverages dynamic provider credentials natively supported by Terraform Cloud/Enterprise.

## Development Workflow

1. **Fork & Branch:** Create a branch for your feature or bug fix.
2. **Write Code:** Modify the Terraform configurations (`main.tf`, `variables.tf`, etc.) following our styling guidelines.
3. **Format:** You MUST run `terraform fmt -recursive` before committing. Unformatted code will fail CI/CD checks.
4. **Open a Pull Request:** Fill out the provided PR template outlining your changes.

## Code Guidelines

* **Minimalism:** Favor readability and simplicity over highly complex abstractions.
* **Variable Descriptions:** Every variable must have a clear `description` and `type`.
* **Version Constraints:** Use the pessimistic operator (`~>`) for provider and module versions to ensure stability without strict lock-in. Pin the Terraform version using `required_version` in the `terraform` block.
* **Naming Conventions:** Use `snake_case` for all resource and variable names. Avoid including the resource type in the name (i.e., `azurerm_management_group.core`, not `azurerm_management_group.mg_core`).

## Security Check

* Never commit `.terraform` folders, `.tfstate` files, or `.tfvars` files containing actual secrets.
* Access secrets securely via workspace variables. Set `sensitive = true` for sensitive variables across all definitions.

If you find a security vulnerability, please refer to our `SECURITY.md` for reporting procedures.
