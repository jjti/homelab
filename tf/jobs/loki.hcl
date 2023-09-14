job "loki" {
  datacenters = ["dc1"]
  type        = "service"

  group "loki" {
    count = 1

    network {
      mode = "host"

      port "loki" {}
    }

    service {
      name = "loki"
      port = "loki"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.loki.rule=PathPrefix(`/loki`)",
        // "traefik.http.routers.loki.middlewares=loki",
        // "traefik.http.middlewares.loki.stripprefix.prefixes=loki",
      ]

      check {
        type     = "http"
        path     = "/ready"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "loki" {
      driver = "docker"

      config {
        image        = "grafana/loki:2.9.0"
        ports        = ["loki"]
        network_mode = "host"
        args         = ["-config.file=${NOMAD_ALLOC_DIR}/config.yaml"]
      }

      template {
        destination = "${NOMAD_ALLOC_DIR}/config.yaml"
        data        = <<EOF
auth_enabled: false

server:
  http_listen_port: {{ env "NOMAD_PORT_loki" }}

common:
  path_prefix: /tmp/loki
  storage:
    s3:
      s3: http://admin:{{ with nomadVar "nomad/jobs/loki" }}{{ .minio_password }}{{ end }}@localhost.:9000/loki
      s3forcepathstyle: true
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  # https://grafana.com/docs/loki/latest/operations/storage/boltdb-shipper/
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: s3
      schema: v11
      index:
        prefix: index_
        period: 24h

storage_config:
  # https://grafana.com/docs/loki/latest/operations/storage/boltdb-shipper/
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/index_cache
    resync_interval: 5s
    shared_store: s3

  aws:
    s3: http://admin:{{ with nomadVar "nomad/jobs/loki" }}{{ .minio_password }}{{ end }}@localhost.:9000/loki
    s3forcepathstyle: true

query_range:
  results_cache: 
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

analytics:
  reporting_enabled: false
EOF
      }
    }
  }
}
