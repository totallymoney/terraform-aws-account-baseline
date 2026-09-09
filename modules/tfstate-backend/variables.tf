variable "bucket_name" {
  type        = string
  description = "Globally unique name for the state bucket."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Must be a valid S3 bucket name."
  }
}

variable "name" {
  type        = string
  description = "Short name used for the KMS alias and the lock table."
}

variable "create_dynamodb_lock_table" {
  type        = bool
  description = "Create a DynamoDB lock table. Not needed if every consumer is on Terraform 1.10 or later and sets use_lockfile = true."
  default     = true
}

variable "noncurrent_version_retention_days" {
  type        = number
  description = "How long to keep superseded state files. They are the only way back after a bad apply."
  default     = 90

  validation {
    condition     = var.noncurrent_version_retention_days >= 30
    error_message = "Keep at least 30 days of history."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource."
  default     = {}
}
