variable "github_idp_client_id" {
  type = string
}

variable "github_idp_client_secret" {
  type      = string
  sensitive = true
}

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

variable "nr_api_key" {
  type      = string
  sensitive = true
}

variable "openvpn_user" {
  type = string
}

variable "openvpn_password" {
  type      = string
  sensitive = true
}

variable "streaming_emails" {
  type = list(string)
}
