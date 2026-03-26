################################################################################
# Variables - AWS Organizations Module
################################################################################

################################################################################
# Organization
################################################################################

variable "create_organization" {
  description = "Whether to create a new AWS Organization. Set to false if an organization already exists."
  type        = bool
  default     = true
}

variable "feature_set" {
  description = "Specify 'ALL' (default) or 'CONSOLIDATED_BILLING'. 'ALL' enables all features including SCPs."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ALL", "CONSOLIDATED_BILLING"], var.feature_set)
    error_message = "feature_set must be 'ALL' or 'CONSOLIDATED_BILLING'."
  }
}

variable "aws_service_access_principals" {
  description = "List of AWS service principals allowed to integrate with the organization."
  type        = list(string)
  default = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "ram.amazonaws.com",
    "ssm.amazonaws.com",
    "sso.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "access-analyzer.amazonaws.com",
    "account.amazonaws.com",
    "controltower.amazonaws.com"
  ]
}

variable "enabled_policy_types" {
  description = "List of policy types to enable in the organization. Requires feature_set = 'ALL'."
  type        = list(string)
  default     = ["SERVICE_CONTROL_POLICY", "TAG_POLICY", "BACKUP_POLICY"]

  validation {
    condition = alltrue([
      for pt in var.enabled_policy_types :
      contains(["AISERVICES_OPT_OUT_POLICY", "BACKUP_POLICY", "SERVICE_CONTROL_POLICY", "TAG_POLICY"], pt)
    ])
    error_message = "Each policy type must be one of: AISERVICES_OPT_OUT_POLICY, BACKUP_POLICY, SERVICE_CONTROL_POLICY, TAG_POLICY."
  }
}

variable "root_id" {
  description = "The root ID of an existing AWS Organization. Required when create_organization = false."
  type        = string
  default     = null
}

################################################################################
# Organizational Units
################################################################################

variable "organizational_units" {
  description = <<-EOT
    List of Organizational Units (OUs) to create. Use parent = "root" for top-level OUs,
    or set parent to the name of another OU defined in this list for nesting (max 2 levels).
    Example:
    [
      { name = "Security",    parent = "root" },
      { name = "Workloads",   parent = "root" },
      { name = "Production",  parent = "Workloads", tags = { Env = "prod" } }
    ]
  EOT
  type = list(object({
    name   = string
    parent = string
    tags   = optional(map(string), {})
  }))
  default = []
}

################################################################################
# Member Accounts
################################################################################

variable "accounts" {
  description = <<-EOT
    List of AWS member accounts to create and manage within the organization.
    Example:
    [
      {
        name      = "prod-workloads"
        email     = "aws+prod@example.com"
        parent_ou = "Production"
      }
    ]
  EOT
  type = list(object({
    name                       = string
    email                      = string
    parent_ou                  = optional(string, null)
    iam_user_access_to_billing = optional(string, "ALLOW")
    role_name                  = optional(string, null)
    close_on_deletion          = optional(bool, false)
    tags                       = optional(map(string), {})
  }))
  default = []
}

variable "default_iam_role_name" {
  description = "Default IAM role name to create in new member accounts for cross-account access."
  type        = string
  default     = "OrganizationAccountAccessRole"
}

################################################################################
# Service Control Policies
################################################################################

variable "service_control_policies" {
  description = <<-EOT
    List of Service Control Policies (SCPs) to create.
    content must be a valid JSON string (AWS IAM policy document).
    Example:
    [
      {
        name        = "DenyRootAccess"
        description = "Deny use of the root user"
        content     = jsonencode({ Version = "2012-10-17", Statement = [...] })
      }
    ]
  EOT
  type = list(object({
    name         = string
    description  = optional(string, "")
    content      = string
    skip_destroy = optional(bool, false)
    tags         = optional(map(string), {})
  }))
  default = []
}

variable "root_policy_attachments" {
  description = "List of SCP names (defined in service_control_policies) to attach to the organization root."
  type        = list(string)
  default     = []
}

variable "ou_policy_attachments" {
  description = "Map of OU name => list of SCP names to attach to that OU."
  type        = map(list(string))
  default     = {}
}

variable "account_policy_attachments" {
  description = "Map of account name => list of SCP names to attach to that account."
  type        = map(list(string))
  default     = {}
}

################################################################################
# Delegated Administrators
################################################################################

variable "delegated_administrators" {
  description = <<-EOT
    List of delegated administrator configurations.
    Example:
    [
      {
        account_id        = "123456789012"
        service_principal = "guardduty.amazonaws.com"
      }
    ]
  EOT
  type = list(object({
    account_id        = string
    service_principal = string
  }))
  default = []
}

################################################################################
# Tagging
################################################################################

variable "tags" {
  description = "Map of tags to apply to all resources created by this module."
  type        = map(string)
  default     = {}
}
