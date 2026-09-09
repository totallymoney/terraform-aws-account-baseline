# terraform-aws-account-baseline

Security baseline for a single AWS account: audit logging, threat detection,
configuration recording, account level guardrails and short lived credentials
for CI.

Run it once per account, before anything else goes in. It is deliberately
small. Every resource here is one that you would otherwise be asked about
during a security review, an audit, or an incident.

## What it creates

| Area | Resources |
|---|---|
| Audit trail | Multi region CloudTrail with log file validation, its own CMK, a versioned S3 bucket that only CloudTrail can write to, and a CloudWatch log group |
| Alarms | Five CloudWatch alarms over the trail: root credential use, repeated denied API calls, IAM policy changes, console sign in without MFA, and changes to the trail itself. All publish to one SNS topic |
| Threat detection | GuardDuty, with S3 data events, EBS malware scanning, RDS login events and Lambda network logs |
| Reporting | Security Hub with the AWS Foundational Security Best Practices and CIS AWS Foundations Benchmark v3.0 standards |
| Configuration history | AWS Config recorder, delivery channel and its own bucket |
| Access review | IAM Access Analyzer for external access findings |
| Account guardrails | S3 account level public access block, EBS encryption by default, block on new public AMI sharing, IMDSv2 as the regional default, IAM password policy |
| Contacts and cost | Security alternate contact, monthly cost budget with forecast and actual alerts |
| CI access | GitHub Actions OIDC provider and roles, pinned to specific repositories |
| State backend | `modules/tfstate-backend`: encrypted state bucket, CMK, access log bucket and lock table |

## What it deliberately does not do

- **Service control policies and organisation settings.** Those belong to the
  management account, not here. If you use AWS Organizations, add a region
  restriction and a deny on leaving the organisation there.
- **Networking.** No VPC, no peering, no transit gateway. Account onboarding and
  workload networking have different lifecycles and different owners.
- **Application resources.** No databases, no clusters, no application KMS keys.
- **IAM Identity Center.** Configure permission sets in the management account.
  This module assumes you sign in through federation and have no IAM users.
- **Multi account rollout.** This applies to the account whose credentials you
  run it with. Wrap it in your own per account configuration, or run it once per
  account.

## Order of operations

The state backend cannot store its own state remotely before it exists, so it
goes first.

```bash
# 1. State backend, with local state
cd examples/tfstate-backend
terraform init
terraform apply

# 2. Move this stack's state into the bucket it just made
terraform output backend_config     # copy into a backend "s3" block
terraform init -migrate-state

# 3. The baseline, using that backend
cd ../complete
terraform init
terraform apply
```

Steps 1 and 3 need administrator credentials. Nothing after this should.

## Usage

```hcl
module "baseline" {
  source = "github.com/<your-org>/terraform-aws-account-baseline?ref=v0.1.0"

  name        = "my-account"
  alarm_email = "security-alerts@example.com"

  monthly_budget_usd         = 500
  budget_notification_emails = ["finops@example.com"]

  create_github_oidc_provider = true

  github_oidc_roles = {
    "my-service-deploy" = {
      subjects = ["repo:my-org/my-service:ref:refs/heads/main"]
      inline_policy_json = data.aws_iam_policy_document.deploy.json
    }
  }
}
```

See [examples/complete](examples/complete) for a full configuration.

## More than one region

CloudTrail is already multi region, and recording global resources such as IAM
in more than one place means paying for the same records repeatedly. For a
second region:

```hcl
module "baseline_secondary" {
  source = "..."
  providers = { aws = aws.secondary }

  name                            = "my-account"
  enable_cloudtrail               = false
  config_include_global_resources = false
}
```

GuardDuty, Security Hub, EBS encryption defaults and IMDSv2 defaults are all
regional, so they are worth applying everywhere you run anything, including
regions you do not use.

## GitHub Actions OIDC

Two things go wrong here often enough to call out.

**Pin the subject.** A trust policy that checks only the `aud` claim trusts every
workflow on GitHub, including one in a fork. Always constrain `sub` to a
repository, and usually to a branch or a GitHub environment:

```
repo:my-org/my-service:ref:refs/heads/main
repo:my-org/my-service:environment:production
```

**Immutable subject claims.** GitHub issues subject claims that include numeric
organisation and repository ids for repositories created recently. If you add
the newer pattern, keep the older one in place as well, or existing
repositories stop being able to assume the role.

The role's permissions are yours to write. `examples/complete` shows a scoped
deploy policy including the `iam:PassRole` condition that ECS deployments need.
A wildcard policy on an OIDC role removes most of the benefit of using OIDC.

## Cost

Everything except two items is free or close to it.

- **AWS Config** is charged per configuration item recorded and per rule
  evaluation. This is usually the largest line. In a quiet account it is a few
  dollars a month; in a busy one with heavy autoscaling it is more. Set
  `enable_config = false` if you accept that most Security Hub controls will
  then report no data.
- **GuardDuty** is charged on CloudTrail event volume, VPC flow log and DNS log
  volume, and separately per feature. Malware scanning is charged per GB
  scanned. Trim `guardduty_features` to what you actually run.

CloudTrail's first copy of management events is free. The S3 and CloudWatch
Logs storage, the KMS keys at one dollar per month each, and Security Hub
checks are all small.

## Requirements

| Name | Version |
|---|---|
| Terraform | >= 1.5.0 (OpenTofu 1.6 or later also works) |
| AWS provider | >= 6.0.0, < 7.0.0 |

## Key inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | string | required | Prefix for every resource. Use something stable, such as the account alias |
| `alarm_email` | string | `null` | Subscribed to the alarm topic. Confirmation arrives by email |
| `enable_cloudtrail` | bool | `true` | Set false if a trail is delivered from a management account |
| `enable_config` | bool | `true` | Set false to avoid the Config bill, at the cost of Security Hub coverage |
| `config_include_global_resources` | bool | `true` | Leave true in one region only |
| `guardduty_features` | list(string) | four features | Trim to what you run |
| `securityhub_standards` | list(string) | FSBP and CIS v3.0 | Also accepts `nist-800-53` and `pci-dss` |
| `security_contact` | object | `null` | Holds personal data. Prefer a shared mailbox and an on call number |
| `monthly_budget_usd` | number | `null` | Monthly cost budget |
| `create_github_oidc_provider` | bool | `false` | One per account |
| `github_oidc_roles` | map(object) | `{}` | Roles CI can assume, pinned to repositories |
| `password_minimum_length` | number | `20` | Minimum is 14 |

Every input is documented in [variables.tf](variables.tf).

## Outputs

`account_id`, `audit_log_kms_key_arn`, `cloudtrail_bucket`, `cloudtrail_arn`,
`security_alarm_topic_arn`, `guardduty_detector_id`, `github_oidc_role_arns`.

## Controls this covers

Mapped to the CIS AWS Foundations Benchmark v3.0 and the AWS Well-Architected
Framework security pillar.

| Control | Where |
|---|---|
| CIS 1.8, 1.9 Password policy length and reuse | `iam.tf` |
| CIS 1.20 IAM Access Analyzer enabled | `iam.tf` |
| CIS 2.1.1 S3 buckets deny unencrypted transport | bucket policies |
| CIS 2.1.4 S3 account level public access block | `account-settings.tf` |
| CIS 2.2.1 EBS encryption by default | `account-settings.tf` |
| CIS 3.1 CloudTrail enabled in all regions | `cloudtrail.tf` |
| CIS 3.3 CloudTrail bucket is not public | `cloudtrail.tf` |
| CIS 3.4 CloudTrail integrated with CloudWatch Logs | `cloudtrail.tf` |
| CIS 3.5 AWS Config enabled | `config.tf` |
| CIS 3.6 CloudTrail bucket access logging | see note below |
| CIS 3.7 CloudTrail encrypted with a CMK | `kms.tf` |
| CIS 3.8 CMK rotation enabled | `kms.tf` |
| CIS 4.1 to 4.4, 4.15 Metric filters and alarms | `alarms.tf` |
| CIS 5.4 Default security group restricts all traffic | see note below |
| SEC 4 Detect and investigate security events | `guardduty.tf`, `securityhub.tf`, `alarms.tf` |
| SEC 8 Protect data at rest | KMS keys, EBS default, bucket encryption |
| SEC 9 Protect data in transit | `DenyInsecureTransport` on every bucket, TLS 1.2 minimum |

Two notes on the gaps.

**CIS 3.6, access logging on the trail bucket.** Not enabled here. Server access
logging on a KMS encrypted bucket needs a second unencrypted bucket, and the
same evidence is available from CloudTrail data events on the bucket, which you
can enable without a second bucket to secure. Choose one and record the choice.

**CIS 5.4, default security groups.** Control Tower deletes default VPCs, and
this module creates none, so there is normally nothing to fix. If your account
still has default VPCs, delete them:

```bash
aws ec2 describe-vpcs --filters Name=isDefault,Values=true \
  --query 'Vpcs[].VpcId' --output text
```

For VPCs you keep, the network module in
[terraform-aws-fargate-service](https://github.com/<your-org>/terraform-aws-fargate-service) empties the
default security group of the VPC it creates.

## Notes on choices

**AWS Config is on by default.** Security Hub controls read from Config. Without
it a Security Hub dashboard shows no failures because nothing was checked,
which is worse than no dashboard at all. It costs money, so the variable exists,
but turn it off knowingly.

**One CMK for all audit logs.** CloudTrail, its log group and Config share one
key with rotation on and the maximum deletion window. Losing that key makes
every log in both buckets unreadable, so the key policy allows the account to
decrypt through S3 but grants nothing the ability to schedule deletion or
rewrite the policy beyond the account administrator.

**The password policy sets no maximum age.** CIS v3.0 dropped the forced rotation
requirement, in line with NIST SP 800-63B. Rotation on a schedule pushes people
towards predictable passwords.

**State files are production data.** They contain every value your configuration
touches, including generated passwords. `modules/tfstate-backend` encrypts the
bucket with a CMK, versions it for rollback, denies unencrypted writes and logs
access to a separate bucket. Grant access to it as narrowly as you would to a
database.

## License

MIT. See [LICENSE](LICENSE).
