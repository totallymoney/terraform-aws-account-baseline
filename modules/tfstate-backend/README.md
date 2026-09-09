# tfstate-backend

Encrypted S3 bucket, CMK, access log bucket and DynamoDB lock table for
Terraform state.

This is the one stack that cannot keep its own state in the bucket before the
bucket exists. Apply it with local state, then migrate.

```bash
terraform init
terraform apply
terraform output backend_config
terraform init -migrate-state
```

The resulting backend block looks like this:

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "account-baseline/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:eu-west-1:000000000000:key/..."
    dynamodb_table = "terraform-my-account-lock"
  }
}
```

`encrypt = true` and `kms_key_id` are not optional here. The bucket policy
denies any write that does not declare `aws:kms` encryption, so a backend
without them fails on the first state write rather than silently storing
plaintext.

## Locking

Terraform 1.10 added native S3 locking. If every consumer of the bucket is on
1.10 or later you can set `use_lockfile = true` in the backend block, set
`create_dynamodb_lock_table = false` here, and drop the table. Until then, keep
the table.

## Why versioning matters

A corrupted or truncated state file is recovered by restoring the previous
object version. Versioning and the retention window are the whole rollback
story, which is why `noncurrent_version_retention_days` has a floor of 30 and
why the bucket and key carry `prevent_destroy`.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `bucket_name` | string | required | Globally unique. An access log bucket is created alongside with a `-logs` suffix |
| `name` | string | required | Short name for the KMS alias and lock table |
| `create_dynamodb_lock_table` | bool | `true` | See locking above |
| `noncurrent_version_retention_days` | number | `90` | Minimum 30 |
| `tags` | map(string) | `{}` | |

## Outputs

`bucket`, `kms_key_arn`, `dynamodb_table`, `backend_config`.
