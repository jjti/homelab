job "fake" {
  datacenters = ["dc1"]
  type        = "service"

  group "fake" {
    count = 1

    network {
      mode = "bridge"
    }

    service {
      name = "whoami-demo"
      port = "80"

      tags = [
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.whoami.rule=PathPrefix(`/fake`)",
      ]

      connect {
        sidecar_service {
          proxy {
            local_service_port = 80
          }
        }
      }

      check {
        expose   = true
        type     = "http"
        name     = "api-health"
        path     = "/health"
        interval = "10s"
        timeout  = "3s"
      }
    }

    task "server" {
      driver = "docker"

      config {
        image = "traefik/whoami"
      }
    }
  }
}
