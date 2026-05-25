output "bucket_name" {
  value = aws_s3_bucket.backup.id
}

output "region" {
  value = var.region
}

output "access_key_id" {
  value = aws_iam_access_key.backup.id
}

# Read with: `cd terraform && terraform output -raw secret_access_key`
output "secret_access_key" {
  value     = aws_iam_access_key.backup.secret
  sensitive = true
}
