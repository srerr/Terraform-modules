################################################################################
# Example: Complete AWS Organizations Setup
# This example provisions a full org structure with SCPs, OUs, and accounts.
################################################################################

provider "aws" {
  region = "us-east-1"

  # Assumes the AWS credentials for the management account are configured.
  # In CI/CD, use an IAM role with the OrganizationsFullAccess policy.
}

module "aws_organizations" {
  source = "../../"

  ############################################################################
  # Organization Settings
  ############################################################################
  create_organization = true
  feature_set         = "ALL"

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "ram.amazonaws.com",
    "ssm.amazonaws.com",
    "sso.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "access-analyzer.amazonaws.com",
    "account.amazonaws.com",
    "controltower.amazonaws.com",
  ]

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
    "BACKUP_POLICY",
  ]

  ############################################################################
  # Organizational Unit Hierarchy
  #
  #  Root
  #  ├── Security
  #  ├── Infrastructure
  #  ├── Workloads
  #  │   ├── Production
  #  │   ├── Staging
  #  │   └── Development
  #  └── Sandbox
  ############################################################################
  organizational_units = [
    # Root Level
    { name = "Security",       parent = "root", tags = { Team = "security" } },
    { name = "Infrastructure", parent = "root", tags = { Team = "platform" } },
    { name = "Workloads",      parent = "root", tags = { Team = "engineering" } },
    { name = "Sandbox",        parent = "root", tags = { Team = "engineering" } },

    # Nested under Workloads
    { name = "Production",  parent = "Workloads", tags = { Env = "prod" } },
    { name = "Staging",     parent = "Workloads", tags = { Env = "staging" } },
    { name = "Development", parent = "Workloads", tags = { Env = "dev" } },
  ]

  ############################################################################
  # Member Accounts
  ############################################################################
  accounts = [
    # Security OU
    {
      name      = "security-audit"
      email     = "aws+security-audit@example.com"
      parent_ou = "Security"
      tags      = { Purpose = "security-tooling" }
    },
    {
      name      = "security-log-archive"
      email     = "aws+log-archive@example.com"
      parent_ou = "Security"
      tags      = { Purpose = "log-archive" }
    },

    # Infrastructure OU
    {
      name      = "infra-network"
      email     = "aws+infra-network@example.com"
      parent_ou = "Infrastructure"
      tags      = { Purpose = "networking" }
    },
    {
      name      = "infra-shared-services"
      email     = "aws+shared-services@example.com"
      parent_ou = "Infrastructure"
      tags      = { Purpose = "shared-services" }
    },

    # Workloads - Production
    {
      name      = "workloads-prod-app"
      email     = "aws+prod-app@example.com"
      parent_ou = "Production"
      tags      = { Env = "prod", AppTier = "application" }
    },
    {
      name      = "workloads-prod-data"
      email     = "aws+prod-data@example.com"
      parent_ou = "Production"
      tags      = { Env = "prod", AppTier = "data" }
    },

    # Workloads - Staging
    {
      name      = "workloads-staging"
      email     = "aws+staging@example.com"
      parent_ou = "Staging"
      tags      = { Env = "staging" }
    },

    # Workloads - Development
    {
      name      = "workloads-dev"
      email     = "aws+dev@example.com"
      parent_ou = "Development"
      tags      = { Env = "dev" }
    },

    # Sandbox
    {
      name      = "sandbox-engineers"
      email     = "aws+sandbox@example.com"
      parent_ou = "Sandbox"
      close_on_deletion = true
      tags      = { Env = "sandbox" }
    },
  ]

  ############################################################################
  # Service Control Policies
  ############################################################################
  service_control_policies = [
    {
      name        = "DenyRootUser"
      description = "Deny all actions performed by the root user"
      content     = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid    = "DenyRootUserActions"
          Effect = "Deny"
          Action = ["*"]
          Resource = ["*"]
          Condition = {
            StringLike = { "aws:PrincipalArn" = ["arn:aws:iam::*:root"] }
          }
        }]
      })
    },
    {
      name        = "DenyLeaveOrg"
      description = "Prevent accounts from leaving the organization"
      content     = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid      = "DenyLeaveOrganization"
          Effect   = "Deny"
          Action   = ["organizations:LeaveOrganization"]
          Resource = ["*"]
        }]
      })
    },
    {
      name        = "ProtectCloudTrail"
      description = "Prevent disabling or modifying CloudTrail"
      content     = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid    = "DenyCloudTrailModification"
          Effect = "Deny"
          Action = [
            "cloudtrail:DeleteTrail",
            "cloudtrail:StopLogging",
            "cloudtrail:UpdateTrail",
            "cloudtrail:PutEventSelectors"
          ]
          Resource = ["*"]
        }]
      })
    },
    {
      name        = "ProtectSecurityServices"
      description = "Prevent disabling GuardDuty and Security Hub"
      content     = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "DenyDisableGuardDuty"
            Effect = "Deny"
            Action = [
              "guardduty:DeleteDetector",
              "guardduty:DisassociateFromMasterAccount",
              "guardduty:StopMonitoringMembers",
              "guardduty:UpdateDetector"
            ]
            Resource = ["*"]
          },
          {
            Sid    = "DenyDisableSecurityHub"
            Effect = "Deny"
            Action = [
              "securityhub:DeleteHub",
              "securityhub:DisableSecurityHub",
              "securityhub:DisassociateFromMasterAccount"
            ]
            Resource = ["*"]
          }
        ]
      })
    },
    {
      name        = "DenyPublicS3"
      description = "Prevent creation of public S3 buckets"
      content     = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid    = "DenyPublicACLs"
          Effect = "Deny"
          Action = ["s3:PutBucketAcl", "s3:PutObjectAcl"]
          Resource = ["*"]
          Condition = {
            StringEqualsAnyValue = {
              "s3:x-amz-acl" = ["public-read", "public-read-write", "authenticated-read"]
            }
          }
        }]
      })
    },
    {
      name        = "SandboxRestrictions"
      description = "Additional cost guardrails for sandbox accounts"
      content     = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid    = "DenyExpensiveInstances"
          Effect = "Deny"
          Action = ["ec2:RunInstances"]
          Resource = ["arn:aws:ec2:*:*:instance/*"]
          Condition = {
            StringNotLike = {
              "ec2:InstanceType" = ["t2.*", "t3.*", "t3a.*"]
            }
          }
        }]
      })
    },
  ]

  ############################################################################
  # SCP Attachments
  ############################################################################

  # Attach baseline SCPs to the root — applies to ALL accounts
  root_policy_attachments = [
    "DenyRootUser",
    "DenyLeaveOrg",
    "ProtectCloudTrail",
  ]

  # Attach SCPs per OU
  ou_policy_attachments = {
    "Workloads"   = ["ProtectSecurityServices", "DenyPublicS3"]
    "Production"  = ["ProtectSecurityServices"]
    "Sandbox"     = ["SandboxRestrictions"]
  }

  ############################################################################
  # Delegated Administrators (replace account IDs after creation)
  ############################################################################
  delegated_administrators = [
    # Uncomment and fill in account IDs after accounts are created
    # {
    #   account_id        = "111111111111"  # security-audit account
    #   service_principal = "guardduty.amazonaws.com"
    # },
    # {
    #   account_id        = "111111111111"
    #   service_principal = "securityhub.amazonaws.com"
    # },
    # {
    #   account_id        = "222222222222"  # security-log-archive account
    #   service_principal = "cloudtrail.amazonaws.com"
    # },
  ]

  ############################################################################
  # Tags applied to all resources
  ############################################################################
  tags = {
    ManagedBy   = "terraform"
    Module      = "terraform-aws-organizations"
    Environment = "management"
    Owner       = "platform-team"
  }
}

################################################################################
# Outputs
################################################################################

output "organization_id" {
  description = "The ID of the AWS Organization"
  value       = module.aws_organizations.organization_id
}

output "organization_root_id" {
  description = "The root ID of the AWS Organization"
  value       = module.aws_organizations.organization_root_id
}

output "all_ou_ids" {
  description = "All OU IDs keyed by OU name"
  value       = module.aws_organizations.all_organizational_unit_ids
}

output "account_ids" {
  description = "All managed account IDs keyed by account name"
  value       = module.aws_organizations.account_ids
  sensitive   = true
}
