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

      port "zipkin" {
        static = 9411
        to     = 9411
      }
    }

    service {
      port = "otlpgrpc"
    }

    service {
      port = "otlphttp"
    }

    service {
      port = "zipkin"
    }

    task "otel" {
      driver = "docker"

      resources {
        cpu = 500
      }

      config {
        image        = "otel/opentelemetry-collector-contrib:0.85.0"
        ports        = ["zipkin"]
        network_mode = "host"
        args         = ["--config=local/config.yaml"]
      }

      # https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/receiver/hostmetricsreceiver#collecting-host-metrics-from-inside-a-container-linux-only
      volume_mount {
        volume           = "root"
        destination      = "/hostfs"
        propagation_mode = "host-to-task"
      }

      template {
        destination = "local/config.yaml"
        data        = <<EOF
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
    exclude:
      - /hostfs/var/nomad/alloc/*/alloc/logs/seqq*
    include_file_path: true

  filelog/seqq:
    include:
      - /hostfs/var/nomad/alloc/*/alloc/logs/seqq*
    include_file_path: true
    attributes:
      entity.name: seqq

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

  prometheus:
    config:
      scrape_configs:
        - job_name: 'traefik'
          scrape_interval: 60s
          static_configs:
            - targets: ['127.0.0.1:8080']

  zipkin:
    endpoint: 127.0.0.1:9411

processors:
  batch:
    send_batch_max_size: 1000
    send_batch_size: 100
    timeout: 60s

  memory_limiter:
    limit_mib: 1024
    spike_limit_mib: 300
    check_interval: 5s

  attributes:
    actions:
      - key: hostname
        value: {{ env "attr.unique.hostname" }} 
        action: insert

  tail_sampling:
    num_traces: 1000
    policies:
      - name: errors
        type: status_code
        status_code: {status_codes: [ERROR, UNSET]}
      - name: sample
        type: probabilistic
        probabilistic:
          sampling_percentage: 5

exporters:
  otlp:
    endpoint: https://otlp.nr-data.net:4318
    headers:
      api-key: {{ with nomadVar "nomad/jobs/otel" }}{{ .nr_api_key }}{{ end }}

service:
  pipelines:
    logs:
      receivers: [filelog, filelog/seqq]
      processors: [attributes, batch, memory_limiter]
      exporters: [otlp]
    metrics:
      receivers: [hostmetrics, otlp, prometheus]
      processors: [attributes, batch, memory_limiter]
      exporters: [otlp]
    traces:
      receivers: [otlp, zipkin]
      processors: [attributes, batch, memory_limiter, tail_sampling]
      exporters: [otlp]
EOF
      }
    }
  }
}
