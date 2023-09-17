job "traefik" {
  datacenters = ["dc1"]
  type        = "system"

  group "traefik" {
    network {
      mode = "host"

      port "http" {
        static = "80"
      }

      port "admin" {
        static = "8080"
      }
    }

    service {
      name = "traefik"
      port = "http"

      tags = [
        "traefik.enable=false",
        "log-${attr.unique.hostname}"
      ]
    }

    service {
      name = "traefik-dashboard"
      port = "admin"

      tags = [
        "traefik.enable=false",
      ]

      check {
        type     = "http"
        path     = "/ping"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:2.10"
        network_mode = "host"
        ports        = ["http", "admin"]
        volumes      = ["local/traefik.yaml:/etc/traefik/traefik.yaml"]
      }

      template {
        destination = "local/traefik.yaml"
        # https://developer.hashicorp.com/nomad/tutorials/load-balancing/load-balancing-traefik
        # https://traefik.io/blog/integrating-consul-connect-service-mesh-with-traefik-2-5/?ref=traefik.io
        data = <<EOF
entryPoints:
  web:
    address: :{{ env "NOMAD_PORT_http" }}
  traefik:
    address: :{{ env "NOMAD_PORT_admin" }}

api:
  dashboard: true
  insecure: true

providers:
  # set up connect catalog
  consulCatalog:
    cache: false
    connectAware: true
    connectByDefault: false
    exposedByDefault: false

    endpoint:
      address: 127.0.0.1:8500
      scheme: http
      token: {{ with nomadVar "nomad/jobs/traefik" }}{{ .read_token }}{{ end }}

metrics:
  prometheus: {}

log:
  level: INFO
  format: json

tracing:
  zipkin: {}

ping: {}
EOF
      }
    }
  }
}
