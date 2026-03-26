# terraform-aws-organizations

A **production-grade** Terraform module for managing [AWS Organizations](https://aws.amazon.com/organizations/), including organizational units (OUs), member accounts, Service Control Policies (SCPs), and delegated administrators.

---

## Features

- 🏢 **Create & manage an AWS Organization** with full feature set
- 🌲 **Hierarchical OUs** — supports root-level and one level of nesting (2 levels total)
- 👤 **Member account lifecycle** — create, tag, and assign accounts to OUs
- 🔒 **Service Control Policies** — create and attach SCPs to the root, OUs, or accounts
- 📋 **9 built-in SCP templates** ready to use (`policies.tf`)
- 🔑 **Delegated administrators** for security services
- 🏷️ **Consistent tagging** across all resources

---

## Architecture

```
Root (Management Account)
├── Security OU
│   ├── security-audit account
│   └── security-log-archive account
├── Infrastructure OU
│   ├── infra-network account
│   └── infra-shared-services account
├── Workloads OU
│   ├── Production OU
│   │   ├── workloads-prod-app account
│   │   └── workloads-prod-data account
│   ├── Staging OU
│   └── Development OU
└── Sandbox OU
```

---

## Requirements

| Name      | Version         |
|-----------|-----------------|
| terraform | >= 1.5.0        |
| aws       | >= 5.0.0, < 6.0 |

---

## Usage

### Minimal Example

```hcl
module "aws_organizations" {
  source = "./terraform-aws-organizations"

  create_organization = true
  feature_set         = "ALL"

  organizational_units = [
    { name = "Security",  parent = "root" },
    { name = "Workloads", parent = "root" },
  ]

  accounts = [
    {
      name      = "security-audit"
      email     = "aws+security-audit@example.com"
      parent_ou = "Security"
    }
  ]

  tags = {
    ManagedBy = "terraform"
  }
}
```

### Full Example

See [`examples/complete/main.tf`](./examples/complete/main.tf) for a complete real-world setup including:
- Full OU hierarchy
- 9 member accounts
- 6 SCPs with root/OU/account attachments
- Delegated administrators

---

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `create_organization` | Whether to create a new AWS Organization | `bool` | `true` | no |
| `feature_set` | `ALL` or `CONSOLIDATED_BILLING` | `string` | `"ALL"` | no |
| `aws_service_access_principals` | AWS services allowed to integrate | `list(string)` | See variables.tf | no |
| `enabled_policy_types` | Policy types to enable | `list(string)` | `["SERVICE_CONTROL_POLICY", "TAG_POLICY", "BACKUP_POLICY"]` | no |
| `root_id` | Existing org root ID (when `create_organization = false`) | `string` | `null` | no |
| `organizational_units` | List of OUs to create | `list(object)` | `[]` | no |
| `accounts` | List of member accounts to create | `list(object)` | `[]` | no |
| `default_iam_role_name` | Default cross-account IAM role name | `string` | `"OrganizationAccountAccessRole"` | no |
| `service_control_policies` | List of SCPs to create | `list(object)` | `[]` | no |
| `root_policy_attachments` | SCP names to attach to the org root | `list(string)` | `[]` | no |
| `ou_policy_attachments` | Map of OU name => SCP names | `map(list(string))` | `{}` | no |
| `account_policy_attachments` | Map of account name => SCP names | `map(list(string))` | `{}` | no |
| `delegated_administrators` | Delegated admin configurations | `list(object)` | `[]` | no |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |

---

## Outputs

| Name | Description |
|------|-------------|
| `organization_id` | The AWS Organization ID |
| `organization_arn` | The AWS Organization ARN |
| `organization_master_account_id` | The management account ID |
| `organization_root_id` | The organization root ID |
| `root_organizational_units` | Map of root OU names => `{ id, arn }` |
| `nested_organizational_units` | Map of nested OU names => `{ id, arn }` |
| `all_organizational_unit_ids` | Combined map of all OU names => IDs |
| `accounts` | Map of account names => `{ id, arn, email, status }` |
| `account_ids` | Map of account names => account IDs |
| `service_control_policies` | Map of SCP names => `{ id, arn }` |
| `delegated_administrators` | Map of delegated admin configs |

---

## Built-in SCPs (`policies.tf`)

The module ships with 9 ready-to-reference SCP content locals in `policies.tf`:

| Local Name | Description |
|------------|-------------|
| `scp_deny_root_user` | Deny all actions performed by the root user |
| `scp_deny_leave_org` | Prevent accounts leaving the org |
| `scp_require_mfa` | Enforce MFA for all IAM console actions |
| `scp_restrict_regions` | Deny actions outside approved regions |
| `scp_protect_cloudtrail` | Prevent CloudTrail deletion/modification |
| `scp_protect_security_services` | Protect GuardDuty and Security Hub |
| `scp_deny_public_s3` | Prevent creation of public S3 buckets |
| `scp_deny_root_access_keys` | Deny creation of root access keys |
| `scp_restrict_ec2_instance_types` | Restrict to approved instance types |

---

## IAM Permissions Required

The AWS credentials used to run this module must have the following managed policies attached to the management account role:

- `AWSOrganizationsFullAccess`
- `iam:CreateRole` (for new account role creation)

---

## Important Notes

1. **AWS Organizations can only be managed from the management account.** Ensure your AWS provider is configured with management account credentials.
2. **Account deletion is irreversible** — `close_on_deletion = true` will permanently close an account when removed from Terraform state.
3. **`prevent_destroy = true`** is set on the Organization resource to prevent accidental destruction.
4. **SCP attachments** — When attaching SCPs to the root, they apply to **all accounts** including the management account (which cannot be restricted by SCPs from within).
5. **Region restrictions in SCPs** — Update the `scp_restrict_regions` allowed regions list to match your organization's approved regions.

---

## File Structure

```
terraform-aws-organizations/
├── main.tf              # Core resources (org, OUs, accounts, SCPs, delegated admins)
├── variables.tf         # All input variables with descriptions and validation
├── outputs.tf           # All module outputs
├── policies.tf          # 9 built-in production SCP content locals
├── versions.tf          # Provider & Terraform version constraints
└── examples/
    └── complete/
        └── main.tf      # Full real-world usage example
```

---

## License

MIT License. See [LICENSE](./LICENSE) for full text.
