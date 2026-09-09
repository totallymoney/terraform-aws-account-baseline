data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region

  # Suffix keeps globally unique names (S3) collision free without
  # putting the account id in the bucket name.
  suffix = substr(sha256("${local.account_id}-${var.name}"), 0, 8)

  cloudtrail_bucket_name = coalesce(var.cloudtrail_bucket_name, "${var.name}-cloudtrail-${local.suffix}")
  config_bucket_name     = coalesce(var.config_bucket_name, "${var.name}-config-${local.suffix}")

  tags = merge(var.tags, { ManagedBy = "terraform" })
}
