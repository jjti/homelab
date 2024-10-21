output "tunnel_password" {
  value     = random_id.tunnel_secret.b64_std
  sensitive = true
}
