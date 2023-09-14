resource "random_password" "minio" {
  length  = 18
  special = false
}

# resource "minio_s3_bucket" "loki" {
#   bucket = "loki"
# }
