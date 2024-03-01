job "arr" {
  datacenters = ["dc1"]

  constraint {
    attribute = "${node.unique.name}"
    value     = "ser5-3"
  }

  group "jellyfin" {
    volume "config" {
      type      = "host"
      source    = "arr-config"
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
      port "http" {
        static = 8096
        to     = 8096
      }
    }

    service {
      port = "http"
    }

    task "jellyfin" {
      driver = "docker"

      config {
        image        = "jellyfin/jellyfin"
        network_mode = "host"
        ports        = ["http"]
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
TZ=Etc/UTC
EOF
      }
    }
  }

  group "sonarr" {
    volume "config" {
      type      = "host"
      source    = "arr-config"
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
      port "http" {
        static = 8989
        to     = 8989
      }
    }

    service {
      port = "http"
    }

    task "sonarr" {
      driver = "docker"

      config {
        image        = "lscr.io/linuxserver/sonarr:latest"
        network_mode = "host"
        ports        = ["http"]
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
      source    = "arr-config"
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
      port "http" {
        static = 8990
        to     = 8989
      }
    }

    service {
      port = "http"
    }

    task "radarr" {
      driver = "docker"

      config {
        image        = "lscr.io/linuxserver/radarr:latest"
        network_mode = "host"
        ports        = ["http"]
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

  group "prowlarr" {
    volume "config" {
      type      = "host"
      source    = "arr-config"
      read_only = false
    }

    network {
      port "http" {
        static = 8991
        to     = 9696
      }
    }

    service {
      port = "http"
    }

    task "prowlarr" {
      driver = "docker"

      config {
        image        = "lscr.io/linuxserver/prowlarr:latest"
        network_mode = "host"
        ports        = ["http"]
      }

      volume_mount {
        volume           = "config"
        destination      = "/config"
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
}
