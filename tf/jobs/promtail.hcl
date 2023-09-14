job "promtail" {
  type = "system"

  group "promtail" {
    count = 1

    network {
      mode = "host"
    }

    task "promtail" {
      driver = "docker"

      config {
        image        = "grafana/promtail:2.9.0"
        network_mode = "host"
        args         = ["-config.file=${NOMAD_ALLOC_DIR}/config.yaml"]
      }

      template {
        destination = "${NOMAD_ALLOC_DIR}/config.yaml"
        data        = <<EOF
server:
  http_listen_port: 0
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  {{ range service "loki" }}
  - url: http://{{ .Address }}:{{ .Port }}/loki/api/v1/push{{ end }}

scrape_configs:
- job_name: system
  static_configs:
  - targets:
      - localhost
    labels:
      nomad_alloc: {{ env "NOMAD_ALLOC_ID" }}
      host: {{ env "node.unique.name" }}
      job: varlogs
      __path__: /var/log/*log
EOF
      }
    }
  }
}