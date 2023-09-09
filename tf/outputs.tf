output "nomad_dev_token" {
  value = nomad_acl_token.token.secret_id
  sensitive = true
}