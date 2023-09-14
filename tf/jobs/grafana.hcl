job "grafana" {
  datacenters = ["dc1"]

  constraint {
    attribute = "${attr.unique.hostname}"
    value     = "ser5-1"
  }

  group "grafana" {
    volume "grafana" {
      type      = "host"
      source    = "grafana"
      read_only = false
    }

    network {
      mode = "host"

      port "http" {
        static = 3000
        to     = 3000
      }
    }

    service {
      name = "grafana"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.grafana.rule=PathPrefix(`/grafana`)"
      ]
    }

    task "grafana" {
      driver = "docker"
      user   = "root"

      config {
        ports        = ["http"]
        image        = "grafana/grafana:latest"
        network_mode = "host"
        args         = ["--config", "${NOMAD_ALLOC_DIR}/config.ini"]
      }

      resources {
        cpu    = 500
        memory = 1000
      }

      volume_mount {
        volume           = "grafana"
        destination      = "/var/lib/grafana" # https://grafana.com/docs/grafana/latest/setup-grafana/configure-docker/#default-paths
        propagation_mode = "private"
      }

      template {
        destination = "${NOMAD_ALLOC_DIR}/config.ini"
        data        = <<EOF
[auth.anonymous]
enabled = true
org_name = Main Org.
org_role = Admin
EOF
      }
    }
  }
}