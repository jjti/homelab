terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state in S3. Real bucket/key/region live in backend.hcl (gitignored)
  # so this public repo doesn't disclose them. Initialize with:
  #   terraform init -backend-config=backend.hcl
  # use_lockfile=true (set in backend.hcl) uses S3-native locking — no DynamoDB
  # table needed (Terraform 1.10+).
  backend "s3" {}
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
  # Hard-fail if the resolved AWS credentials map to a different account than
  # var.aws_account_id. Prevents apply-into-wrong-account when multiple
  # profiles are configured locally.
  allowed_account_ids = [var.aws_account_id]
}

# Cheap-but-still-readable bucket for nightly rclone backups of Immich originals
# and a pg_dump. Current versions go in whatever class rclone uploads as
# (configured to GLACIER_IR on the client). Lifecycle below pushes superseded
# versions into Deep Archive and eventually expires them.
resource "aws_s3_bucket" "backup" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_public_access_block" "backup" {
  bucket                  = aws_s3_bucket.backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning gives a 30-day-ish history for nightly overwrites of the db dump,
# and undoes accidental deletes/storage-template migrations in the library.
resource "aws_s3_bucket_versioning" "backup" {
  bucket = aws_s3_bucket.backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "backup" {
  bucket = aws_s3_bucket.backup.id

  rule {
    id     = "cold-history"
    status = "Enabled"
    filter {}

    # A superseded version (e.g. yesterday's db dump after tonight's upload)
    # stays in its current class for 7 days, then transitions to Deep Archive,
    # and is deleted after a year.
    noncurrent_version_transition {
      noncurrent_days = 7
      storage_class   = "DEEP_ARCHIVE"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }

    # Stale incomplete multipart uploads cost real money — clean them up.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Dedicated IAM user. Scoped to this bucket — compromise of the access key on
# bazz can only read/write/delete inside the configured bucket.
resource "aws_iam_user" "backup" {
  name = "immich-backup"
}

resource "aws_iam_access_key" "backup" {
  user = aws_iam_user.backup.name
}

data "aws_iam_policy_document" "backup" {
  statement {
    sid    = "BucketLevel"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:GetBucketLocation",
    ]
    resources = [aws_s3_bucket.backup.arn]
  }

  statement {
    sid    = "ObjectLevel"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = ["${aws_s3_bucket.backup.arn}/*"]
  }
}

resource "aws_iam_user_policy" "backup" {
  name   = "backup-rw"
  user   = aws_iam_user.backup.name
  policy = data.aws_iam_policy_document.backup.json
}
