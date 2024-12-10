variable "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  type        = string
  default     = "custom-terraform-state-bucket-123456"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  type        = string
  default     = "custom-terraform-state-locks"
}