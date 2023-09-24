job "etcd" {
  datacenters = ["dc1"]
  type        = "system"

  group "etcd" {
    volume "etcd" {
      type      = "host"
      source    = "etcd"
      read_only = false
    }

    network {
      mode = "host"

      port "peer" {
        static = 2380
        to     = 2380
      }

      port "client" {
        static = 2379
        to     = 2379
      }

      port "metrics" {
        static = 2381
        to     = 2381
      }
    }

    service {
      name = "etcd-peer"
      port = "peer"
    }

    service {
      name = "etcd-client"
      port = "client"
    }

    service {
      name = "etcd-metrics"
      port = "metrics"

      check {
        type     = "http"
        port     = "metrics"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "etcd" {
      driver = "docker"

      config {
        image        = "quay.io/coreos/etcd:v3.4.27"
        ports        = ["peer", "client", "metrics"]
        network_mode = "host"
      }

      volume_mount {
        volume           = "etcd"
        destination      = "/usr/local/var/lib/etcd"
        propagation_mode = "private"
      }

      template {
        destination = ".env"
        env         = true
        // https://etcd.io/docs/v3.3/op-guide/clustering/#static
        data = <<EOF
ETCD_DATA_DIR                    = '/usr/local/var/lib/etcd'
ETCD_LOGGER                      = 'zap'

ETCD_NAME                        = '{{ env "attr.unique.hostname" }}'
ETCD_INITIAL_ADVERTISE_PEER_URLS = 'http://{{ env "attr.unique.network.ip-address" }}:{{ env "NOMAD_PORT_peer" }}'
ETCD_LISTEN_PEER_URLS            = 'http://{{ env "attr.unique.network.ip-address" }}:{{ env "NOMAD_PORT_peer" }}'
ETCD_LISTEN_CLIENT_URLS          = 'http://{{ env "attr.unique.network.ip-address" }}:{{ env "NOMAD_PORT_client" }},http://127.0.0.1:{{ env "NOMAD_PORT_client" }}'
ETCD_ADVERTISE_CLIENT_URLS       = 'http://{{ env "attr.unique.network.ip-address" }}:{{ env "NOMAD_PORT_client" }}'
ETCD_INITIAL_CLUSTER             = '{{ $first := true }}{{ range service "consul" }}{{ if $first }}{{ $first = false }}{{ else }},{{ end }}{{ .Node }}=http://{{ .Address }}:2380{{ end }}'
ETCD_INITIAL_CLUSTER_STATE       = 'new'

ETCD_LISTEN_METRICS_URLS         = 'http://{{ env "attr.unique.network.ip-address" }}:{{ env "NOMAD_PORT_metrics" }}'
EOF
      }
    }
  }
}
