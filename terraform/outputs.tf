output "cloudflare_service_token_id" {
  value     = cloudflare_access_service_token.token.client_id
  sensitive = true
}

output "cloudflare_service_token_secret" {
  value     = cloudflare_access_service_token.token.client_secret
  sensitive = true
}

output "nomad_read_token" {
  value     = nomad_acl_token.read.secret_id
  sensitive = true
}

output "nomad_write_token" {
  value     = nomad_acl_token.write.secret_id
  sensitive = true
}

output "tunnel_password" {
  value     = random_id.tunnel_secret.b64_std
  sensitive = true
}
