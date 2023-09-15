# https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/examples/nomad/otel-collector.nomad
job "otel" {
  datacenters = ["dc1"]
  type        = "system"

  group "otel" {
    volume "root" {
      type      = "host"
      source    = "root"
      read_only = true
    }

    network {
      mode = "host"

      port "otlpgrpc" {
        static = 4317
        to     = 4317
      }

      port "otlphttp" {
        static = 4318
        to     = 4318
      }
    }

    service {
      port = "otlpgrpc"
    }

    service {
      port = "otlphttp"
    }

    task "otel" {
      driver = "docker"

      config {
        image = "otel/opentelemetry-collector-contrib:0.85.0"
        ports = ["otlpgrpc", "otlphttp"]
        entrypoint = [
          "/otelcol-contrib",
          "--config=local/config.yaml",
        ]
      }

      # https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/hostmetricsreceiver#collecting-host-metrics-from-inside-a-container-linux-only
      volume_mount {
        volume           = "root"
        destination      = "/hostfs"
        propagation_mode = "host-to-task"
      }

      template {
        destination = "local/config.yaml"
        data        = <<EOH
---
receivers:
  otlp:
    protocols:
      grpc:
      http:

  filelog:
    include:
      - /hostfs/var/nomad/alloc/*/alloc/logs/*
      - /hostfs/var/log/consul/*
    include_file_path: true

  journald:
    directory: /hostfs/var/log/journal/
    units:
      - consul
      - nomad
    priority: info

  hostmetrics:
    root_path: /hostfs
    collection_interval: 60s
    scrapers:
      paging:
        metrics:
          system.paging.utilization:
            enabled: true
      cpu:
        metrics:
          system.cpu.utilization:
            enabled: true
      disk:
      filesystem:
        metrics:
          system.filesystem.utilization:
            enabled: true
      load:
      memory:
      network:
      processes:

processors:
  batch:
    send_batch_max_size: 1000
    send_batch_size: 100
    timeout: 60s
  memory_limiter:
    limit_mib: 1024
    spike_limit_mib: 300
    check_interval: 5s

exporters:
  otlp:
    endpoint: https://otlp.nr-data.net:4318
    headers:
      api-key: {{ with nomadVar "nomad/jobs/otel" }}{{ .nr_api_key }}{{ end }}

service:
  pipelines:
    logs:
      receivers: [filelog]
      processors: [batch, memory_limiter]
      exporters: [otlp]
    metrics:
      receivers: [hostmetrics]
      processors: [batch, memory_limiter]
      exporters: [otlp]
EOH
      }
    }
  }
}
