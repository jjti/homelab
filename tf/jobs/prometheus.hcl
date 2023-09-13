job "prometheus" {
  datacenters = ["dc1"]

  group "prometheus" {
    network {
      port "http" {}

      mode = "host"
    }

    service {
      name = "prometheus-http"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.prometheus.rule=PathPrefix(`/prometheus`)",
      ]
    }

    task "scrape" {
      driver = "docker"


      config {
        image = "prom/prometheus:latest"
        ports = ["http"]
      }

      template {
        destination = "config.yaml"
        data        = <<EOF
global:

alerting:

rule_files:

scrape_configs:
  - job_name: "traefik"
    static_configs:
      - targets:
      {{- range nomadService "traefik-admin-http" }}
        - {{ .Address }}:{{ .Port }}
      {{- end}}
EOF
      }
    }
  }
}