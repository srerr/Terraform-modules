################################################################################
# Outputs - AWS Organizations Module
################################################################################

################################################################################
# Organization
################################################################################

output "organization_id" {
  description = "The ID of the AWS Organization."
  value       = var.create_organization ? aws_organizations_organization.this[0].id : null
}

output "organization_arn" {
  description = "The ARN of the AWS Organization."
  value       = var.create_organization ? aws_organizations_organization.this[0].arn : null
}

output "organization_master_account_id" {
  description = "The AWS account ID of the master/management account."
  value       = var.create_organization ? aws_organizations_organization.this[0].master_account_id : null
}

output "organization_master_account_arn" {
  description = "The ARN of the master/management account."
  value       = var.create_organization ? aws_organizations_organization.this[0].master_account_arn : null
}

output "organization_master_account_email" {
  description = "The email address of the master/management account."
  value       = var.create_organization ? aws_organizations_organization.this[0].master_account_email : null
}

output "organization_root_id" {
  description = "The ID of the organization root."
  value       = var.create_organization ? aws_organizations_organization.this[0].roots[0].id : var.root_id
}

output "organization_root_arn" {
  description = "The ARN of the organization root."
  value       = var.create_organization ? aws_organizations_organization.this[0].roots[0].arn : null
}

output "organization_feature_set" {
  description = "The feature set of the organization (ALL or CONSOLIDATED_BILLING)."
  value       = var.create_organization ? aws_organizations_organization.this[0].feature_set : null
}

################################################################################
# Organizational Units
################################################################################

output "root_organizational_units" {
  description = "Map of root-level OU names to their attributes."
  value = {
    for k, v in aws_organizations_organizational_unit.root : k => {
      id  = v.id
      arn = v.arn
    }
  }
}

output "nested_organizational_units" {
  description = "Map of nested (level 2) OU names to their attributes."
  value = {
    for k, v in aws_organizations_organizational_unit.level_2 : k => {
      id  = v.id
      arn = v.arn
    }
  }
}

output "all_organizational_unit_ids" {
  description = "Combined map of ALL OU names to their IDs, regardless of level."
  value = merge(
    { for k, v in aws_organizations_organizational_unit.root : k => v.id },
    { for k, v in aws_organizations_organizational_unit.level_2 : k => v.id }
  )
}

################################################################################
# Member Accounts
################################################################################

output "accounts" {
  description = "Map of account names to their attributes (id, arn, email, status)."
  value = {
    for k, v in aws_organizations_account.this : k => {
      id     = v.id
      arn    = v.arn
      email  = v.email
      status = v.status
    }
  }
}

output "account_ids" {
  description = "Map of account names to their AWS Account IDs."
  value       = { for k, v in aws_organizations_account.this : k => v.id }
}

################################################################################
# Service Control Policies
################################################################################

output "service_control_policies" {
  description = "Map of SCP names to their IDs and ARNs."
  value = {
    for k, v in aws_organizations_policy.scp : k => {
      id  = v.id
      arn = v.arn
    }
  }
}

################################################################################
# Delegated Administrators
################################################################################

output "delegated_administrators" {
  description = "Map of delegated administrator configurations that were created."
  value = {
    for k, v in aws_organizations_delegated_administrator.this : k => {
      account_id        = v.account_id
      service_principal = v.service_principal
    }
  }
}
