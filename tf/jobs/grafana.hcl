job "grafana" {
  datacenters = ["dc1"]

  group "grafana" {
    network {
      port "http" {
        to = 3000
      }
    }

    service {
      name = "grafana-http"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.grafana.rule=PathPrefix(`/grafana`)"
      ]
    }

    task "grafana" {
      driver = "docker"

      config {
        ports = ["http"]
        image = "grafana/grafana:latest"
        args  = ["--config", "${NOMAD_ALLOC_DIR}/config.ini"]
      }

      template {
        destination = "${NOMAD_ALLOC_DIR}/config.ini"
        data        = <<EOF
[server]
domain = joshuatimmons.com
root_url = %(protocol)s://%(domain)s:%(http_port)s/grafana/
serve_from_sub_path = true
EOF
      }
    }
  }
}