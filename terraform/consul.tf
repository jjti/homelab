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

# Cannot resolve below
# https://github.com/hashicorp/nomad/issues/8647

# │ Error: failed to set 'global' config entry: Unexpected response code: 500 (service "traefik" has protocol "tcp", which does not match defined listener protocol "http")
# │ 
# │   with consul_config_entry.proxy_defaults,
# │   on consul.tf line 36, in resource "consul_config_entry" "proxy_defaults":
# │   36: resource "consul_config_entry" "proxy_defaults" {
# │ 
# ╵

# resource "consul_config_entry" "proxy_defaults" {
#   kind = "proxy-defaults"

#   # Note that only "global" is currently supported for proxy-defaults and that
#   # Consul will override this attribute if you set it to anything else.
#   name = "global"

#   config_json = jsonencode({
#     Config = {
#       protocol = "http"
#     }
#   })
# }
