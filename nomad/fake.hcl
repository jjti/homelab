job "fake" {
  datacenters = ["dc1"]
  type        = "service"

  group "fake" {
    count = 2

    network {
      mode = "bridge"

      port "fake" {}
    }

    service {
      name = "whoami-demo"
      port = "fake"

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
    }

    task "server" {
      driver = "docker"

      config {
        image = "traefik/whoami"
        ports = ["fake"]
      }
    }
  }
}
