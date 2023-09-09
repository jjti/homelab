output "nomad_write_token" {
  value     = nomad_acl_token.write.secret_id
  sensitive = true
}

output "nomad_read_token" {
  value     = nomad_acl_token.read.secret_id
  sensitive = true
}

output "traefik_password" {
  value     = random_password.traefik.result
  sensitive = true
}
