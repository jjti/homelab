job "pihole" {
  datacenters = ["dc1"]
  type        = "system"

  update {
    max_parallel = 0
  }

  group "pihole" {
    network {
      port "dns" {
        static = 53
      }

      port "dashboard" {}
    }

    service {
      name = "pihole"
      port = "dashboard"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.pihole.rule=PathPrefix(`/admin`)",
      ]
    }

    task "pihole" {
      driver = "docker"

      config {
        image        = "pihole/pihole:latest"
        network_mode = "host"
        ports        = ["dns", "dashboard"]
      }

      template {
        destination = ".env"
        env         = true
        data        = <<EOF
TZ          = America/New_York
WEB_PORT    = {{ env "NOMAD_PORT_dashboard" }}
WEBPASSWORD = {{ with nomadVar "nomad/jobs/pihole" }}{{ .password }}{{ end }}
EOF
      }
    }
  }
}
