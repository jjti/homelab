job "arr" {
  datacenters = ["dc1"]

  constraint {
    attribute = "${node.unique.name}"
    value     = "ser5-3"
  }

  group "jellyfin" {
    volume "config" {
      type      = "host"
      source    = "arr-config-jellyfin"
      read_only = false
    }

    volume "cache" {
      type      = "host"
      source    = "arr-cache"
      read_only = false
    }

    volume "tv" {
      type      = "host"
      source    = "arr-tv"
      read_only = false
    }

    volume "movies" {
      type      = "host"
      source    = "arr-movies"
      read_only = false
    }

    network {
      mode = "bridge"

      port "http" {
        static = 8096
        to     = 8096
      }
    }

    service {
      name = "jellyfin"
      port = "http"

      connect {
        sidecar_service {}
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.jellyfin.rule=PathPrefix(`/stream`)",
      ]
    }

    task "jellyfin" {
      driver = "docker"

      resources {
        cpu    = 2000
        memory = 8000
      }

      config {
        image = "lscr.io/linuxserver/jellyfin:latest"
        ports = ["http"]
      }

      volume_mount {
        volume           = "config"
        destination      = "/config"
        propagation_mode = "private"
      }

      volume_mount {
        volume           = "cache"
        destination      = "/cache"
        propagation_mode = "private"
      }

      volume_mount {
        volume           = "tv"
        destination      = "/media1/tv"
        propagation_mode = "private"
      }

      volume_mount {
        volume           = "movies"
        destination      = "/media2/movies"
        propagation_mode = "private"
      }

      template {
        destination = ".env"
        env         = true
        data        = <<EOF
PUID=1000
PGID=1000
TZ= Etc/UTC
JELLYFIN_PublishedServerUrl=192.168.0.139
EOF
      }
    }
  }

  group "jellyseer" {
    volume "config" {
      type      = "host"
      source    = "arr-config-jellyseer"
      read_only = false
    }

    network {
      mode = "bridge"

      port "http" {
        static = 5055
        to     = 5055
      }
    }

    service {
      name = "jellyseer"
      port = "http"

      connect {
        sidecar_service {}
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.jellyseer.rule=PathPrefix(`/download`)",
      ]
    }

    task "jellyseer" {
      driver = "docker"

      config {
        image = "fallenbagel/jellyseerr:latest"
        ports = ["http"]
      }

      volume_mount {
        volume           = "config"
        destination      = "/app/config"
        propagation_mode = "private"
      }

      template {
        destination = ".env"
        env         = true
        data        = <<EOF
PUID=1000
PGID=1000
TZ= Etc/UTC
EOF
      }
    }
  }

  group "sonarr" {
    volume "config" {
      type      = "host"
      source    = "arr-config-sonarr"
      read_only = false
    }

    volume "tv" {
      type      = "host"
      source    = "arr-tv"
      read_only = false
    }

    volume "downloads" {
      type      = "host"
      source    = "arr-downloads"
      read_only = false
    }

    network {
      mode = "bridge"

      port "http" {
        static = 8989
        to     = 8989
      }
    }

    service {
      name = "sonarr"
      port = "http"

      connect {
        sidecar_service {}
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.sonarr.rule=PathPrefix(`/sonarr`)",
      ]
    }

    task "sonarr" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/sonarr:latest"
        ports = ["http"]
      }

      volume_mount {
        volume           = "config"
        destination      = "/config"
        propagation_mode = "private"
      }

      volume_mount {
        volume           = "tv"
        destination      = "/tv"
        propagation_mode = "private"
      }

      volume_mount {
        volume           = "downloads"
        destination      = "/downloads"
        propagation_mode = "private"
      }

      template {
        destination = ".env"
        env         = true
        data        = <<EOF
PUID=1000
PGID=1000
TZ=Etc/UTC
EOF
      }
    }
  }

  group "radarr" {
    volume "config" {
      type      = "host"
      source    = "arr-config-radarr"
      read_only = false
    }

    volume "movies" {
      type      = "host"
      source    = "arr-movies"
      read_only = false
    }

    volume "downloads" {
      type      = "host"
      source    = "arr-downloads"
      read_only = false
    }

    network {
      mode = "bridge"

      port "http" {
        static = 7878
        to     = 7878
      }
    }

    service {
      name = "radarr"
      port = "http"

      connect {
        sidecar_service {}
      }

      tags = [
        "traefik.enable=true",
        "traefik.consulcatalog.connect=true",
        "traefik.http.routers.radarr.rule=PathPrefix(`/radarr`)",
      ]
    }

    task "radarr" {
      driver = "docker"

      config {
        image = "lscr.io/linuxserver/radarr:latest"
        ports = ["http"]
      }

      volume_mount {
        volume           = "config"
        destination      = "/config"
        propagation_mode = "private"
      }

      volume_mount {
        volume           = "movies"
        destination      = "/movies"
        propagation_mode = "private"
      }

      volume_mount {
        volume           = "downloads"
        destination      = "/downloads"
        propagation_mode = "private"
      }

      template {
        destination = ".env"
        env         = true
        data        = <<EOF
PUID=1000
PGID=1000
TZ=Etc/UTC
EOF
      }
    }
  }

  group "sabnzbd" {
    volume "config" {
      type      = "host"
      source    = "arr-config-sabnzbd"
      read_only = false
    }

    volume "downloads" {
      type      = "host"
      source    = "arr-downloads"
      read_only = false
    }

    network {
      mode = "bridge"

      port "ui" {
        static = 6882
        to     = 8080
      }

      port "http" {
        static = 6881
        to     = 6881
      }
    }

    service {
      name = "sabnzbd-ui"
      port = "ui"

      connect {
        sidecar_service {}
      }
    }

    service {
      name = "sabnzbd-http"
      port = "http"

      connect {
        sidecar_service {}
      }
    }

    task "sabnzbd" {
      driver = "docker"

      resources {
        cpu    = 1000
        memory = 2000
      }

      config {
        image = "lscr.io/linuxserver/sabnzbd:latest"
        ports = ["ui", "http"]
      }

      volume_mount {
        volume           = "config"
        destination      = "/config"
        propagation_mode = "private"
      }

      volume_mount {
        volume           = "downloads"
        destination      = "/downloads"
        propagation_mode = "private"
      }

      template {
        destination = ".env"
        env         = true
        data        = <<EOF
GUID=1000
PUID=1000
TZ=Etc/UTC
EOF
      }
    }
  }
}