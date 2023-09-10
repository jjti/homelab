variable "nomad_token" {
  type = string
}

job "traefik" {
  datacenters = ["dc1"]
  type        = "system"

  group "traefik" {
    network {
      port "http" {
        static = 80
      }

      port "admin" {
        static = 8080
      }
    }

    service {
      name     = "traefik-http"
      provider = "nomad"
      port     = "http"

      tags = ["traefik.enable=false"]
    }

    service {
      name     = "traefik-admin-http"
      provider = "nomad"
      port     = "admin"

      tags = ["traefik.enable=false"]
    }

    task "server" {
      driver = "docker"

      config {
        image        = "traefik:2.10"
        network_mode = "host"
        ports        = ["http", "admin"]
        args = [
          "--api.insecure=true",
          "--api.dashboard=true",
          "--entrypoints.web.address=:${NOMAD_PORT_http}",
          "--entrypoints.traefik.address=:${NOMAD_PORT_admin}",

          # https://doc.traefik.io/traefik/providers/nomad/
          "--providers.nomad=true",
          "--providers.nomad.endpoint.address=http://${NOMAD_IP_http}:4646",
          "--providers.nomad.endpoint.token=${var.nomad_token}",
        ]
      }
    }
  }
}
