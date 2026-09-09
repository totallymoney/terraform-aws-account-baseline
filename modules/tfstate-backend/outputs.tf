output "bucket" {
  description = "State bucket name, for the `bucket` argument of the s3 backend."
  value       = aws_s3_bucket.state.id
}

output "kms_key_arn" {
  description = "State CMK, for the `kms_key_id` argument of the s3 backend."
  value       = aws_kms_key.state.arn
}

output "dynamodb_table" {
  description = "Lock table, for the `dynamodb_table` argument of the s3 backend."
  value       = try(aws_dynamodb_table.lock[0].name, null)
}

output "backend_config" {
  description = "Drop this into a backend block, adding your own key."
  value = {
    bucket         = aws_s3_bucket.state.id
    region         = local.region
    encrypt        = true
    kms_key_id     = aws_kms_key.state.arn
    dynamodb_table = try(aws_dynamodb_table.lock[0].name, null)
  }
}
