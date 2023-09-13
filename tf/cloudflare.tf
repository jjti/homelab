# https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/deployment-guides/terraform/

locals {
  nomad_hostname = "nomad.${var.cloudflare_domain}"
}

resource "cloudflare_record" "record" {
  name    = "@"
  zone_id = var.cloudflare_zone_id
  value   = "0.0.0.0"
  type    = "A"
  proxied = false
}

resource "cloudflare_record" "record_www" {
  name    = "www"
  zone_id = var.cloudflare_zone_id
  value   = var.cloudflare_domain
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "record_nomad" {
  name    = "nomad"
  zone_id = var.cloudflare_zone_id
  value   = cloudflare_tunnel.auto_tunnel.cname
  type    = "CNAME"
  proxied = true
}

resource "random_id" "tunnel_secret" {
  byte_length = 35
}

resource "cloudflare_tunnel" "auto_tunnel" {
  name       = "homelab"
  account_id = var.cloudflare_account_id
  secret     = random_id.tunnel_secret.b64_std
}

resource "cloudflare_tunnel_config" "auto_tunnel" {
  tunnel_id  = cloudflare_tunnel.auto_tunnel.id
  account_id = var.cloudflare_account_id

  config {
    origin_request {
      no_tls_verify = true
    }

    ingress_rule {
      service = "http://localhost:4646"
    }
  }
}

###
# Nomad
###

resource "cloudflare_access_application" "nomad" {
  zone_id                   = var.cloudflare_zone_id
  name                      = "homelab nomad access"
  domain                    = local.nomad_hostname
  type                      = "self_hosted"
  session_duration          = "2h"
  auto_redirect_to_identity = true
  allowed_idps              = []
}

resource "cloudflare_access_policy" "nomad_token" {
  application_id = cloudflare_access_application.nomad.id
  zone_id        = var.cloudflare_zone_id
  name           = "homelab service principal access policy"
  precedence     = "1"
  decision       = "non_identity"

  include {
    service_token = [cloudflare_access_service_token.token.id]
  }
}

resource "cloudflare_access_service_token" "token" {
  zone_id = var.cloudflare_zone_id
  name    = "homelab-token"
}
