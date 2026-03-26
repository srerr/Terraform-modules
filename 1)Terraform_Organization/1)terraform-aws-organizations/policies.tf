################################################################################
# Built-in Service Control Policies
# Reference-ready production SCPs - use these via the service_control_policies variable
################################################################################

locals {
  ##############################################################################
  # SCP: Deny Root User Actions
  ##############################################################################
  scp_deny_root_user = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyRootUserActions"
        Effect = "Deny"
        Action = ["*"]
        Resource = ["*"]
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = ["arn:aws:iam::*:root"]
          }
        }
      }
    ]
  })

  ##############################################################################
  # SCP: Deny Leaving Organization
  ##############################################################################
  scp_deny_leave_org = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyLeaveOrganization"
        Effect   = "Deny"
        Action   = ["organizations:LeaveOrganization"]
        Resource = ["*"]
      }
    ]
  })

  ##############################################################################
  # SCP: Enforce MFA for IAM Actions
  ##############################################################################
  scp_require_mfa = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyWithoutMFA"
        Effect = "Deny"
        NotAction = [
          "iam:CreateVirtualMFADevice",
          "iam:EnableMFADevice",
          "iam:GetUser",
          "iam:ListMFADevices",
          "iam:ListVirtualMFADevices",
          "iam:ResyncMFADevice",
          "sts:GetSessionToken"
        ]
        Resource = ["*"]
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })

  ##############################################################################
  # SCP: Restrict Allowed Regions
  ##############################################################################
  scp_restrict_regions = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyOutsideAllowedRegions"
        Effect = "Deny"
        NotAction = [
          "a4b:*", "acm:*", "aws-marketplace-management:*", "aws-marketplace:*",
          "aws-portal:*", "budgets:*", "ce:*", "chime:*", "cloudfront:*",
          "config:*", "cur:*", "directconnect:*", "ec2:DescribeRegions",
          "ec2:DescribeTransitGateways", "ec2:DescribeVpnGateways",
          "fms:*", "globalaccelerator:*", "health:*", "iam:*",
          "importexport:*", "kms:*", "mobileanalytics:*", "networkmanager:*",
          "organizations:*", "pricing:*", "route53:*", "route53domains:*",
          "route53resolver:*", "s3:GetAccountPublic*", "s3:ListAllMyBuckets",
          "s3:ListMultiRegionAccessPoints", "s3:PutAccountPublic*",
          "shield:*", "sts:*", "support:*", "trustedadvisor:*",
          "waf-regional:*", "waf:*", "wafv2:*", "wellarchitected:*"
        ]
        Resource = ["*"]
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = [
              "us-east-1",
              "us-east-2",
              "us-west-2",
              "eu-west-1"
            ]
          }
        }
      }
    ]
  })

  ##############################################################################
  # SCP: Deny Disabling CloudTrail
  ##############################################################################
  scp_protect_cloudtrail = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyCloudTrailModification"
        Effect = "Deny"
        Action = [
          "cloudtrail:DeleteTrail",
          "cloudtrail:StopLogging",
          "cloudtrail:UpdateTrail",
          "cloudtrail:PutEventSelectors"
        ]
        Resource = ["*"]
      }
    ]
  })

  ##############################################################################
  # SCP: Deny Disabling Security Hub & GuardDuty
  ##############################################################################
  scp_protect_security_services = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDisableGuardDuty"
        Effect = "Deny"
        Action = [
          "guardduty:DeleteDetector",
          "guardduty:DisassociateFromMasterAccount",
          "guardduty:DisassociateMembers",
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
          "securityhub:DisassociateFromMasterAccount",
          "securityhub:DisassociateMembers"
        ]
        Resource = ["*"]
      }
    ]
  })

  ##############################################################################
  # SCP: Deny Public S3 Buckets
  ##############################################################################
  scp_deny_public_s3 = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyPublicS3Access"
        Effect = "Deny"
        Action = [
          "s3:PutBucketPublicAccessBlock",
          "s3:PutAccountPublicAccessBlock"
        ]
        Resource = ["*"]
        Condition = {
          Bool = {
            "s3:DataAccessPointAccount" = "false"
          }
        }
      },
      {
        Sid    = "DenyPublicACLs"
        Effect = "Deny"
        Action = [
          "s3:PutBucketAcl",
          "s3:PutObjectAcl"
        ]
        Resource = ["*"]
        Condition = {
          StringEqualsAnyValue = {
            "s3:x-amz-acl" = [
              "public-read",
              "public-read-write",
              "authenticated-read"
            ]
          }
        }
      }
    ]
  })

  ##############################################################################
  # SCP: Deny Creation of IAM Access Keys for Root
  ##############################################################################
  scp_deny_root_access_keys = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyRootAccessKeys"
        Effect = "Deny"
        Action = ["iam:CreateAccessKey"]
        Resource = ["arn:aws:iam::*:root"]
      }
    ]
  })

  ##############################################################################
  # SCP: Restrict EC2 Instance Types (Cost Control)
  ##############################################################################
  scp_restrict_ec2_instance_types = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyLargeInstanceTypes"
        Effect = "Deny"
        Action = ["ec2:RunInstances"]
        Resource = ["arn:aws:ec2:*:*:instance/*"]
        Condition = {
          StringNotLike = {
            "ec2:InstanceType" = [
              "t2.*", "t3.*", "t3a.*",
              "m5.*", "m5a.*", "m6i.*",
              "c5.*", "c5a.*", "c6i.*",
              "r5.*", "r6i.*"
            ]
          }
        }
      }
    ]
  })

  ##############################################################################
  # Exported SCP Map (reference by name in your module call)
  ##############################################################################
  builtin_scps = {
    "DenyRootUser"              = local.scp_deny_root_user
    "DenyLeaveOrg"              = local.scp_deny_leave_org
    "RequireMFA"                = local.scp_require_mfa
    "RestrictRegions"           = local.scp_restrict_regions
    "ProtectCloudTrail"         = local.scp_protect_cloudtrail
    "ProtectSecurityServices"   = local.scp_protect_security_services
    "DenyPublicS3"              = local.scp_deny_public_s3
    "DenyRootAccessKeys"        = local.scp_deny_root_access_keys
    "RestrictEC2InstanceTypes"  = local.scp_restrict_ec2_instance_types
  }
}
