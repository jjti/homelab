resource "random_password" "traefik" {
  length           = 24
  special          = false
}

resource "nomad_acl_policy" "write" {
  name = "write"

  rules_hcl = <<EOT
namespace "default" {
  policy = "write"
}
EOT
}

resource "nomad_acl_token" "write" {
  name     = "write"
  type     = "client"
  policies = [nomad_acl_policy.write.name]
}

resource "nomad_acl_policy" "read" {
  name = "read"

  rules_hcl = <<EOT
namespace "default" {
  policy = "read"
}
EOT
}

resource "nomad_acl_token" "read" {
  name     = "read"
  type     = "client"
  policies = [nomad_acl_policy.read.name]
}

resource "nomad_job" "traefik" {
  hcl2 {
    vars = {
      "nomad_token" = nomad_acl_token.read.secret_id,
      "traefik_password" = random_password.traefik.result,
    }
  }

  jobspec = file("${path.module}/jobs/traefik.hcl")
}
