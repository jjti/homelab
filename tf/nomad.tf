resource "nomad_acl_policy" "default" {
  name        = "default"

  rules_hcl = <<EOT
namespace "default" {
  policy = "write"
}
EOT
}

resource "nomad_acl_token" "token" {
  name     = "client"
  type     = "client"
  policies = [nomad_acl_policy.default.name]
}
