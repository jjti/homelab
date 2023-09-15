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

agent {
  policy = "read"
}

node {
  policy = "read"
}
EOT
}

resource "nomad_acl_token" "read" {
  name     = "read"
  type     = "client"
  policies = [nomad_acl_policy.read.name]
}

resource "nomad_variable" "traefik" {
  path = "nomad/jobs/traefik"
  items = {
    read_token = data.consul_acl_token_secret_id.traefik.secret_id
  }
}

resource "nomad_variable" "pihole" {
  path = "nomad/jobs/pihole"
  items = {
    password = random_id.pihole_password.b64_std
  }
}

resource "nomad_variable" "minio" {
  path = "nomad/jobs/minio"
  items = {
    minio_password = random_password.minio.result
  }
}

resource "nomad_variable" "otel" {
  path = "nomad/jobs/otel"
  items = {
    nr_api_key = var.nr_api_key
  }
}

resource "nomad_job" "jobs" {
  for_each = fileset(path.module, "../nomad/*")

  jobspec = file("${path.module}/${each.key}")
}
