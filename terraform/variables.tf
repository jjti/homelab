variable "minio_admin_password" {
  type      = string
  sensitive = true
}

variable "minio_access_key" {
  type      = string
  sensitive = true
}

variable "minio_secret_key" {
  type      = string
  sensitive = true
}

variable "pihole_password" {
  type      = string
  sensitive = true
}

variable "tailscale_oauth_key" {
  type      = string
  sensitive = true
}

variable "tailscale_oauth_secret" {
  type      = string
  sensitive = true
}

