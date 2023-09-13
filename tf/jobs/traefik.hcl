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
      name = "traefik-http"
      port = "http"

      tags = ["traefik.enable=false"]
    }

    service {
      name = "traefik-admin-http"
      port = "admin"

      tags = ["traefik.enable=false"]
    }

    task "server" {
      driver = "docker"

      config {
        image        = "traefik:2.10"
        network_mode = "host"
        ports        = ["http", "admin"]
        volumes      = ["local/traefik.yaml:/etc/traefik/traefik.yaml"]
      }

      template {
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
  consulCatalog:
    exposedByDefault: false
    connectAware: true
    cache: false
    connectByDefault: false

    endpoint:
      address: {{ env "NOMAD_IP_http" }}:8500
      scheme: http
      token: {{ with nomadVar "nomad/jobs/traefik" }}{{ .read_token }}{{ end }}

metrics:
  prometheus: true
EOF

        destination = "local/traefik.yaml"
      }
    }
  }
}
