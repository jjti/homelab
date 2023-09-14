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
      mode = "host"

      port "api" {
        static = "9000" # unsure how to remove this since the minio services need to find one another
      }

      port "console" {
        static = "9001"
      }
    }

    service {
      name = "minio"
      port = "api"

      check {
        type     = "http"
        path     = "/minio/health/live"
        interval = "10s"
        timeout  = "2s"
      }
    }

    service {
      name = "minio-console"
      port = "console"

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
        ports        = ["api", "console"]
        network_mode = "host"
        args = [
          "server",
          "--address", ":${NOMAD_PORT_api}",
          "--console-address", ":${NOMAD_PORT_console}",
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
MINIO_VOLUMES       = '{{ range service "consul" }}http://{{ .Address }}:9000/mnt/sata {{ end }}'
MINIO_ROOT_USER     = admin
MINIO_ROOT_PASSWORD = {{ with nomadVar "nomad/jobs/minio" }}{{ .password }}{{ end }}
EOF
      }
    }
  }
}
