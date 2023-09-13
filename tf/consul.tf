resource "consul_acl_policy" "traefik" {
  name  = "traefik"
  rules = <<EOF
key_prefix "traefik" {
  policy = "write"
}

service "traefik" {
  policy = "write"
}

agent_prefix "" {
  policy = "read"
}

node_prefix "" {
  policy = "read"
}

service_prefix "" {
  policy = "read"
}
EOF
}

resource "consul_acl_token" "traefik" {
  policies    = [consul_acl_policy.traefik.name]
  description = "read access for traefik"
}

data "consul_acl_token_secret_id" "traefik" {
  accessor_id = consul_acl_token.traefik.id
}
