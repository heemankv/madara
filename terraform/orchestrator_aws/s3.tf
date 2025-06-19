# --- S3 Bucket for Madara Orchestrator ---

# Construct the S3 bucket name
locals {
  s3_bucket_name = "${var.madara_orchestrator_aws_prefix}-${var.s3_bucket_identifier}"
}

# Define the S3 bucket resource
resource "aws_s3_bucket" "orchestrator_bucket" {
  bucket = local.s3_bucket_name
  # ACL set to private. For more granular control, aws_s3_bucket_acl could be used.
  # However, the recommended approach is to use aws_s3_bucket_public_access_block
  # and IAM policies for access control rather than ACLs.
  # Setting acl = "private" is a common baseline.
}

# Configure bucket ACL (alternative to direct acl in aws_s3_bucket)
# This ensures the bucket is private.
resource "aws_s3_bucket_acl" "orchestrator_bucket_acl" {
  bucket = aws_s3_bucket.orchestrator_bucket.id
  acl    = "private"
}

# Enable versioning for the S3 bucket
resource "aws_s3_bucket_versioning" "orchestrator_bucket_versioning" {
  bucket = aws_s3_bucket.orchestrator_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Configure server-side encryption for the S3 bucket (SSE-S3)
resource "aws_s3_bucket_server_side_encryption_configuration" "orchestrator_bucket_sse" {
  bucket = aws_s3_bucket.orchestrator_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

# Block all public access to the S3 bucket
resource "aws_s3_bucket_public_access_block" "orchestrator_bucket_public_access_block" {
  bucket = aws_s3_bucket.orchestrator_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Optional: Lifecycle policy to manage object versions or transitions (e.g., to Glacier)
# resource "aws_s3_bucket_lifecycle_configuration" "orchestrator_bucket_lifecycle" {
#   bucket = aws_s3_bucket.orchestrator_bucket.id
#
#   rule {
#     id      = "log"
#     status  = "Enabled"
#
#     filter {
#       prefix = "logs/"
#     }
#
#     transition {
#       days          = 30
#       storage_class = "STANDARD_IA"
#     }
#
#     transition {
#       days          = 60
#       storage_class = "GLACIER"
#     }
#
#     expiration {
#       days = 90
#     }
#   }
#
#   rule {
#     id     = "tmp"
#     status = "Enabled"
#
#     filter {
#       prefix = "tmp/"
#     }
#
#     expiration {
#       days = 1
#     }
#   }
# }
