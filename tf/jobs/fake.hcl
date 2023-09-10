job "fake" {
  datacenters = ["dc1"]
  type        = "service"

  group "fake" {
    count = 1

    network {
      port "http" {}
    }

    service {
      name     = "whoami-demo"
      provider = "nomad"
      port     = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.http.rule=PathPrefix(`/fake`)",
      ]
    }

    task "server" {
      env {
        WHOAMI_PORT_NUMBER = "${NOMAD_PORT_http}"
      }

      driver = "docker"

      config {
        image = "traefik/whoami"
        ports = ["http"]
      }
    }
  }
}
