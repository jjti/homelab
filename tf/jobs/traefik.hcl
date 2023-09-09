variable "nomad_token" {
    type = string
}

variable "traefik_password" {
    type = string
}

job "traefik" {
    datacenters = ["dc1"]
    type        = "service"

    spread {
        attribute = node.datacenter
        weight    = 100
    }

    group "traefik" {
        count = 3

        network {
            port "http"{
                static = 80
            }

            port "admin"{
                static = 8080
            }
        }

        service {
            name = "traefik-http"
            provider = "nomad"
            port = "http"
        }

        service {
            name = "traefik-admin-http"
            provider = "nomad"
            port = "admin"
        }

        task "server" {
            driver = "docker"

            config {
                image = "traefik:2.10"
                ports = ["http", "admin"]
                args = [
                    "--api.insecure=true",
                    "--api.dashboard=true",
                    "--entrypoints.web.address=:${NOMAD_PORT_http}",
                    "--entrypoints.traefik.address=:${NOMAD_PORT_admin}",
                    # https://doc.traefik.io/traefik/providers/nomad/
                    "--providers.nomad=true",
                    "--providers.nomad.endpoint.address=http://localhost:4646",
                    "--providers.nomad.endpoint.token=${var.nomad_token}",
                ]
            }
        }
    }
}
