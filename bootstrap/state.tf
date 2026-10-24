resource "aws_kms_key" "state" {
  description              = "${var.name_prefix} Terraform state and lockfile encryption"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = true
  deletion_window_in_days  = 30

  # Standard account delegation: IAM policies must still authorize key users.
  # Account administrators retain key administration. CI permissions are scoped
  # separately in identity.tf; no role references are needed in this policy.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "EnableAccountIAMDelegation"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.aws_account_id}:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })

  tags = { Name = "${var.name_prefix}-terraform-state" }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket" "state" {
  bucket        = var.state_bucket_name
  force_destroy = false

  tags = { Name = var.state_bucket_name }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket                = aws_s3_bucket.state.id
  expected_bucket_owner = var.aws_account_id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket                = aws_s3_bucket.state.id
  expected_bucket_owner = var.aws_account_id

  rule {
    # Identity policies scope KMS encryption context to exact object ARNs.
    # Enabling S3 Bucket Keys would change that context to the bucket ARN.
    bucket_key_enabled = false

    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
        Condition = {
          Bool = {
            "aws:SecureTransport"       = "false"
            "aws:PrincipalIsAWSService" = "false"
          }
        }
      },
      {
        Sid       = "RequireSSEKMSHeader"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.state.arn}/*"
        Condition = {
          StringNotEquals = { "s3:x-amz-server-side-encryption" = "aws:kms" }
        }
      },
      {
        Sid       = "RequireStateKeyHeader"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.state.arn}/*"
        Condition = {
          StringNotEquals = { "s3:x-amz-server-side-encryption-aws-kms-key-id" = aws_kms_key.state.arn }
        }
      }
    ]
  })

  # These deny statements require explicit headers, including during recovery.
  # Bucket defaults alone do not satisfy a PutObject without the required headers.
  depends_on = [aws_s3_bucket_public_access_block.state]
}
