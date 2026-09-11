# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0]

First release.

- CloudTrail, multi region, log file validation, its own CMK, delivered to S3
  and CloudWatch Logs
- Five CloudWatch alarms over the trail, publishing to one SNS topic
- GuardDuty and Security Hub findings routed to the same topic through
  EventBridge, with readable message templates
- GuardDuty with configurable features
- Security Hub with AWS Foundational Security Best Practices and CIS AWS
  Foundations Benchmark v5.0.0
- AWS Config, with `CONTINUOUS` or `DAILY` recording and an optional resource
  type list
- IAM Access Analyzer, password policy
- S3 account public access block, EBS encryption by default, blocked public AMI
  sharing, IMDSv2 as the regional default
- Security alternate contact, monthly budget, Cost Explorer anomaly detection
- GitHub Actions OIDC provider and roles pinned to repositories
- `modules/tfstate-backend`: encrypted state bucket, CMK, access log bucket,
  lock table
