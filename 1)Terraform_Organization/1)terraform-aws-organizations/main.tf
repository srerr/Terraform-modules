################################################################################
# AWS Organizations - Root Module
# Production-Grade Terraform Module
################################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

################################################################################
# Organization
################################################################################

resource "aws_organizations_organization" "this" {
  count = var.create_organization ? 1 : 0

  aws_service_access_principals = var.aws_service_access_principals
  enabled_policy_types          = var.enabled_policy_types
  feature_set                   = var.feature_set

  lifecycle {
    prevent_destroy = true
  }
}

################################################################################
# Organizational Units (Root Level)
################################################################################

resource "aws_organizations_organizational_unit" "root" {
  for_each = { for ou in var.organizational_units : ou.name => ou if ou.parent == "root" }

  name      = each.value.name
  parent_id = var.create_organization ? aws_organizations_organization.this[0].roots[0].id : var.root_id
  tags      = merge(var.tags, try(each.value.tags, {}))
}

################################################################################
# Organizational Units (Nested - Level 2)
################################################################################

resource "aws_organizations_organizational_unit" "level_2" {
  for_each = {
    for ou in var.organizational_units : ou.name => ou
    if ou.parent != "root" && !contains(keys(aws_organizations_organizational_unit.root), ou.parent)
  }

  name      = each.value.name
  parent_id = aws_organizations_organizational_unit.root[each.value.parent].id
  tags      = merge(var.tags, try(each.value.tags, {}))

  depends_on = [aws_organizations_organizational_unit.root]
}

################################################################################
# Member Accounts
################################################################################

resource "aws_organizations_account" "this" {
  for_each = { for acct in var.accounts : acct.name => acct }

  name                       = each.value.name
  email                      = each.value.email
  iam_user_access_to_billing = try(each.value.iam_user_access_to_billing, "ALLOW")
  role_name                  = try(each.value.role_name, var.default_iam_role_name)
  close_on_deletion          = try(each.value.close_on_deletion, false)

  parent_id = try(
    aws_organizations_organizational_unit.root[each.value.parent_ou].id,
    aws_organizations_organizational_unit.level_2[each.value.parent_ou].id,
    var.create_organization ? aws_organizations_organization.this[0].roots[0].id : var.root_id
  )

  tags = merge(
    var.tags,
    { "AccountName" = each.value.name },
    try(each.value.tags, {})
  )

  lifecycle {
    ignore_changes = [role_name, iam_user_access_to_billing]
  }
}

################################################################################
# Service Control Policies (SCPs)
################################################################################

resource "aws_organizations_policy" "scp" {
  for_each = { for p in var.service_control_policies : p.name => p }

  name        = each.value.name
  description = try(each.value.description, "Managed by Terraform")
  content     = each.value.content
  type        = "SERVICE_CONTROL_POLICY"
  skip_destroy = try(each.value.skip_destroy, false)

  tags = merge(var.tags, try(each.value.tags, {}))
}

################################################################################
# SCP Attachments - Organization Root
################################################################################

resource "aws_organizations_policy_attachment" "root" {
  for_each = {
    for attachment in var.root_policy_attachments : attachment => attachment
  }

  policy_id = aws_organizations_policy.scp[each.value].id
  target_id = var.create_organization ? aws_organizations_organization.this[0].roots[0].id : var.root_id
}

################################################################################
# SCP Attachments - Organizational Units
################################################################################

resource "aws_organizations_policy_attachment" "ou" {
  for_each = {
    for item in flatten([
      for ou_name, policies in var.ou_policy_attachments : [
        for policy in policies : {
          key       = "${ou_name}:${policy}"
          ou_name   = ou_name
          policy    = policy
        }
      ]
    ]) : item.key => item
  }

  policy_id = aws_organizations_policy.scp[each.value.policy].id
  target_id = try(
    aws_organizations_organizational_unit.root[each.value.ou_name].id,
    aws_organizations_organizational_unit.level_2[each.value.ou_name].id
  )
}

################################################################################
# SCP Attachments - Accounts
################################################################################

resource "aws_organizations_policy_attachment" "account" {
  for_each = {
    for item in flatten([
      for acct_name, policies in var.account_policy_attachments : [
        for policy in policies : {
          key       = "${acct_name}:${policy}"
          acct_name = acct_name
          policy    = policy
        }
      ]
    ]) : item.key => item
  }

  policy_id = aws_organizations_policy.scp[each.value.policy].id
  target_id = aws_organizations_account.this[each.value.acct_name].id
}

################################################################################
# Delegated Administrators
################################################################################

resource "aws_organizations_delegated_administrator" "this" {
  for_each = {
    for da in var.delegated_administrators : "${da.account_id}-${da.service_principal}" => da
  }

  account_id        = each.value.account_id
  service_principal = each.value.service_principal

  depends_on = [aws_organizations_account.this]
}
