resource "random_password" "minio" {
  length  = 18
  special = false
}
