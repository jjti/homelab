variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "cloudflare_domain" {
  type = string
}

variable "github_idp_client_id" {
  type = string
}

variable "github_idp_client_secret" {
  type = string
}

variable "minio_access_key" {
  type = string
}

variable "minio_secret_key" {
  type = string
}

variable "nr_api_key" {
  type = string
}

variable "openvpn_user" {
  type = string
}

variable "openvpn_password" {
  type = string
}

variable "streaming_emails" {
  type = list(string)
}
