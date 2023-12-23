job "minio" {
  datacenters = ["dc1"]
  type        = "system"

  update {
    max_parallel = 0
  }

  group "minio" {
    volume "minio" {
      type      = "host"
      source    = "sata"
      read_only = false
    }

    network {
      mode = "host"

      port "api" {
        static = 9000
        to     = 9000
      }

      port "console" {
        static = 9001
        to     = 9001
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
        image        = "minio/minio:RELEASE.2023-12-23T07-19-11Z"
        ports        = ["api", "console"]
        network_mode = "host"
        args = [
          "server",
          "--address", ":${NOMAD_PORT_api}",
          "--console-address", ":${NOMAD_PORT_console}",
          "--json",
        ]
      }

      resources {
        cpu    = 1000
        memory = 6000
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
MINIO_ROOT_PASSWORD = {{ with nomadVar "nomad/jobs/minio" }}{{ .minio_password }}{{ end }}
MINIO_ROOT_USER     = admin
MINIO_VOLUMES       = '{{ range service "consul" }}http://{{ .Address }}:{{ env "NOMAD_PORT_api" }}/mnt/sata {{ end }}'
EOF
      }
    }
  }
}
