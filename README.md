<!-- BEGIN_TF_DOCS -->
# AWS EKA with VSO+CSI for Vault Integration

## Permissions

## Authentications

## Features

## Documentation

## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.5.0)

- <a name="requirement_aws"></a> [aws](#requirement\_aws) (6.37.0)

- <a name="requirement_helm"></a> [helm](#requirement\_helm) (3.1.1)

- <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) (3.0.1)

- <a name="requirement_null"></a> [null](#requirement\_null) (3.2.4)

- <a name="requirement_random"></a> [random](#requirement\_random) (3.8.1)

- <a name="requirement_time"></a> [time](#requirement\_time) (0.13.1)

- <a name="requirement_tls"></a> [tls](#requirement\_tls) (4.2.1)

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

### <a name="input_customer_name"></a> [customer\_name](#input\_customer\_name)

Description: Specify the name of your customer. This helps to customize the resources created for your customer.

Type: `string`

### <a name="input_salesforce_opportunity_id"></a> [salesforce\_opportunity\_id](#input\_salesforce\_opportunity\_id)

Description: If you are using this demo as part of a sales opportunity, enter your Salesforce Opportunity ID (example: '006RO00000D2qo6XXX') or Opportunity Number (example: 'O-123456') here. Otherwise, enter 'internal'.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_ddr_tfc_organization"></a> [ddr\_tfc\_organization](#input\_ddr\_tfc\_organization)

Description: n/a

Type: `string`

Default: `""`

### <a name="input_ddr_tfc_project_name"></a> [ddr\_tfc\_project\_name](#input\_ddr\_tfc\_project\_name)

Description: n/a

Type: `string`

Default: `""`

### <a name="input_ddr_user_email"></a> [ddr\_user\_email](#input\_ddr\_user\_email)

Description: n/a

Type: `string`

Default: `""`

### <a name="input_ddr_user_id"></a> [ddr\_user\_id](#input\_ddr\_user\_id)

Description: n/a

Type: `string`

Default: `""`

### <a name="input_ddr_user_name"></a> [ddr\_user\_name](#input\_ddr\_user\_name)

Description: n/a

Type: `string`

Default: `""`

### <a name="input_ddr_user_project_id"></a> [ddr\_user\_project\_id](#input\_ddr\_user\_project\_id)

Description: n/a

Type: `string`

Default: `""`

### <a name="input_ddr_user_project_name"></a> [ddr\_user\_project\_name](#input\_ddr\_user\_project\_name)

Description: n/a

Type: `string`

Default: `""`

### <a name="input_ddr_user_slug"></a> [ddr\_user\_slug](#input\_ddr\_user\_slug)

Description: The DDR user slug to use for this demo.

Type: `string`

Default: `""`

### <a name="input_ddr_vault_public_endpoint"></a> [ddr\_vault\_public\_endpoint](#input\_ddr\_vault\_public\_endpoint)

Description: n/a

Type: `string`

Default: `""`

### <a name="input_ddr_vault_root_namespace"></a> [ddr\_vault\_root\_namespace](#input\_ddr\_vault\_root\_namespace)

Description: n/a

Type: `string`

Default: `""`

### <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type)

Description: The EC2 instance type to use for the EKS worker nodes.

Type: `string`

Default: `"t2.medium"`

### <a name="input_region"></a> [region](#input\_region)

Description: The AWS region to use for this demo.

Type: `string`

Default: `"us-west-2"`

### <a name="input_step_2"></a> [step\_2](#input\_step\_2)

Description: Set to `true` once initial run is complete.

Type: `bool`

Default: `false`

### <a name="input_step_3"></a> [step\_3](#input\_step\_3)

Description: Set to `true` once `step_2` run is complete.

Type: `bool`

Default: `false`

## Resources

The following resources are used by this module:

- [aws_eip.nginx_ingress](https://registry.terraform.io/providers/hashicorp/aws/6.37.0/docs/resources/eip) (resource)
- [helm_release.nginx_ingress](https://registry.terraform.io/providers/hashicorp/helm/3.1.1/docs/resources/release) (resource)
- [helm_release.vault_secrets_operator](https://registry.terraform.io/providers/hashicorp/helm/3.1.1/docs/resources/release) (resource)
- [kubernetes_cluster_role_binding_v1.vault](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/cluster_role_binding_v1) (resource)
- [kubernetes_deployment_v1.static_app](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/deployment_v1) (resource)
- [kubernetes_ingress_v1.apps](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/ingress_v1) (resource)
- [kubernetes_manifest.vault_csi_secret](https://registry.terraform.io/providers/hashicorp/kubernetes/3.0.1/docs/resources/manifest) (resource)
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

## Outputs

The following outputs are exported:

### <a name="output_kubernetes_info"></a> [kubernetes\_info](#output\_kubernetes\_info)

Description: (Optional) Use this command to configure kubectl to access the EKS cluster

### <a name="output_vault_address"></a> [vault\_address](#output\_vault\_address)

Description: Use this address to login to the Vault UI

### <a name="output_vault_namespace"></a> [vault\_namespace](#output\_vault\_namespace)

Description: Switch to this namespace to locate the resources for this demo

### <a name="output_website"></a> [website](#output\_website)

Description: Use this address to access the VSO demo

<!-- markdownlint-enable -->
## External Documentation
<!-- END_TF_DOCS -->