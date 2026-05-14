# Copyright IBM Corp. 2024, 2026

variable "ddr_user_slug" {
  description = "The DDR user slug to use for this demo."
  type        = string
  default     = ""
}

variable "customer_name" {
  description = "Specify the name of your customer. This helps to customize the resources created for your customer."
  type        = string

  validation {
    condition     = length(var.customer_name) <= 50 && can(regex("^[a-z0-9-]*$", var.customer_name))
    error_message = "Customer name must be 50 characters or less and can only contain lowercase letters, numbers, and hyphens"
  }
}

variable "region" {
  description = "The AWS region to use for this demo."
  type        = string
  default     = "us-west-2"
}

variable "step_2" {
  description = "Set to `true` once initial run is complete."
  type        = bool
  default     = false
}

variable "step_3" {
  description = "Set to `true` once `step_2` run is complete."
  type        = bool
  default     = false
}

variable "instance_type" {
  description = "The EC2 instance type to use for the EKS worker nodes."
  type        = string
  default     = "t2.medium"
}

## REQUIRED: SFDC Opportunity ID
## All DDR demos must include this variable, as it will be used to track the
## usage of DDR during sales opportunities. This helps us quantify the impact
## and value of DDR as a sales tool. When editing this file, *do not* remove
## this variable or change its name.
variable "salesforce_opportunity_id" {
  description = "If you are using this demo as part of a sales opportunity, enter your Salesforce Opportunity ID (example: '006RO00000D2qo6XXX') or Opportunity Number (example: 'O-123456') here. Otherwise, enter 'internal'."
  type        = string
  validation {
    condition     = length(var.salesforce_opportunity_id) == 15 || length(var.salesforce_opportunity_id) == 18 || var.salesforce_opportunity_id == "internal" || can(regex("^O-\\d{6}$", var.salesforce_opportunity_id))
    error_message = "Please provide a valid Salesforce Opportunity ID or Opportunity Number, or enter 'internal'."
  }
}