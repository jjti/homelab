job "minio" {
  datacenters = ["dc1"]
  type        = "system"

  group "minio" {
    volume "minio" {
      type      = "host"
      source    = "sata"
      read_only = false
    }

    network {
      port "minio-api" {
        static = 9000
      }

      port "minio-console" {
        static = 9001
      }
    }

    service {
      name = "minio-api"
      port = "minio-api"

      check {
        type     = "http"
        path     = "/minio/health/live"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "minio-console"
      port = "minio-console"

      tags = [
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.whoami.rule=PathPrefix(`/minio`)",
      ]

      # TODO MINIO_SERVER_URL?
      # https://min.io/docs/minio/linux/reference/minio-server/minio-server.html#envvar.MINIO_SERVER_URL

      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "minio" {
      driver = "docker"

      config {
        image        = "minio/minio:RELEASE.2023-08-16T20-17-30Z.hotfix.60799aeb0"
        network_mode = "host"
        ports        = ["minio-api", "minio-console"]
        args = ["server",
          "--address", ":${NOMAD_PORT_minio_api}",
          "--console-address", ":${NOMAD_PORT_minio_console}",
          "http://192.168.0.13{7...9}:${NOMAD_PORT_minio_api}/mnt/sata",
        ]
      }

      volume_mount {
        volume           = "minio"
        destination      = "/mnt/sata"
        propagation_mode = "private"
      }

      template {
        destination = ".env"
        env         = true
        data        = <<EOF
MINIO_ROOT_USER     = admin
MINIO_ROOT_PASSWORD = {{ with nomadVar "nomad/jobs/minio" }}{{ .password }}{{ end }}
EOF
      }
    }
  }
}
