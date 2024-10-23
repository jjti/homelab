# Homelab

## Hardware

<img width="500px" src="https://github.com/jjti/homelab/assets/13923102/6a97ead1-d26e-4056-8fbc-c2fc2da03fb1" />

The homelab is made up of three [Beelink Mini SER5 Maxes](https://www.bee-link.com/beelink-amd-ryzen-5-ser5-5800u-minip-26183466). Each has 32 GB DDR4 of memory and 500 GB of NVMe storage. I also added [2 TB of SSD storage to each](https://www.amazon.com/dp/B07YD5F561). So in total there's:

- 24 cores / 48 threads
- 96 GiB memory
- 1.5 TiB NVMe storage and 6 TiB SATA storage

The main reason I opt'ed the SER5 Max was they're cheap (~$350 each), have low power draw (advertised at 54 W per node), and they don't take up much space. That said, everything is slower in these compared to a consumer desktop: the 5800H is a laptop CPU, storage is over PCIe 3 not 4, and it's DDR4 memory. That's all fine though since this is to tinker.

## Deployment

### Terraform

I use Kubernetes resources created via manifests applied with Terraform.

```bash
# kubectl apply, helm install, etc
make tf
```

## Access

There's two types of accessibility for the homelab:

1. HTTP API access to services and Nomad
2. SSH access to the homelab nodes

I used [Cloudflare Tunnels](#cloudflare-tunnel) for address both. I create one egress configuration rule pointing at Traefik (for HTTP access to hosted APIs) and another pointing at the SSH server for remote access to Nomad, Consul, etc. I use `sshuttle` to get remote access to the result of services in the homelab.

### Cloudflare Tunnel

I want to dispatch Nomad jobs into the homelab from Github Actions. I thought about setting up a daemon that pulls configs from an S3 bucket that I push to Github Actions, to avoid exposing my home network to the internet, but opted instead for a Cloudflare Tunnel (throwing security concerns in the garbage).

```bash
curl -H "CF-Access-Client-Id: xx" -H "CF-Access-Client-Secret: xx" -v https://nomad.homelab.com
```

I didn't choose [Tailscale Funnels](https://tailscale.com/kb/1247/funnel-serve-use-cases/) or Ngrok because Cloudflare has some extra nice-to-have features like domain management, access policies, IdP-support, etc.

<details>
<summary>Cloudflare configuration</summary>

Each node runs `cloudflared` for a `cloudflare_tunnel` created with Terraform. The `cloudflared` process points at the Nomad endpoint on each host:

```hcl
// creating a tunnel with a secret
resource "cloudflare_tunnel" "auto_tunnel" {
  name       = "homelab"
  secret     = random_id.tunnel_secret.b64_std
}

// configuring egress to Nomad
resource "cloudflare_tunnel_config" "auto_tunnel" {
  tunnel_id  = cloudflare_tunnel.auto_tunnel.id
  account_id = var.cloudflare_account_id

  config {
    ingress_rule {
      service = "http://localhost:4646"
    }
  }
}

// skipping stuff

// making an access policy associated w/ the domain that uses a cloudflare service token
resource "cloudflare_access_policy" "nomad_token" {
  application_id = cloudflare_access_application.nomad.id
  zone_id        = var.cloudflare_zone_id
  precedence     = "1"
  decision       = "non_identity"

  include {
    service_token = [cloudflare_access_service_token.token.id]
  }
}

// make the service token for machine <> machine calls
resource "cloudflare_access_service_token" "token" {
  zone_id = var.cloudflare_zone_id
  name    = "homelab-token"
}

```

I can then use the access service token (`cloudflare_access_service_token.token` above) to access Nomad remotely:

```bash
# this calls the nomad api
curl -H "CF-Access-Client-Id: xx" -H "CF-Access-Client-Secret: xx" -v https://nomad.homelab.com
```

</details>

### sshuttle

I use a combination and `sshuttle` and `cloudflared` to access services' UIs when not at home like `sshuttle -NHr homelab 0/0`.

- [Cloudflare Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Connect with SSH through Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/use-cases/ssh/)
- [sshuttle usage](https://sshuttle.readthedocs.io/en/stable/usage.html)

<details>
<summary>sshuttle configuration</summary>

I do it with an ingress rule for `cloudflared` using Github as an IdP:

```hcl
  config {
    // ingress rule pointing at the ssh server
    ingress_rule {
      hostname = "ssh.homelab.com"
      service  = "ssh://localhost:22"
    }

    ingress_rule {
      service = "http://localhost:4646"
    }
```

A configuration for my client `ssh` to use `cloudflared` as a proxy:

```txt
Host homelab
    ProxyCommand cloudflared access ssh --hostname ssh.homelab.com
    StrictHostKeyChecking no
    User josh
```

And can then remotely access any service in the homelab with `sshuttle -NHr homelab 0/0`.

</details>

## Storage

### MinIO

MinIO is a distributed storage engine with an S3-compatible interface. It means I can write data from one node into MinIO and access it from applications running on other nodes, and have some redundancy during deployments or restarts of any one of the nodes.

<details>
<summary>MinIO configuration</summary>

I tried hard to make Ceph work. I wanted both a distributed filesystem plus an S3-compatible API. I tried `cephadm`, `ceph-ansible`, hoping from node to node running `systemctl restart ceph-mon`... I hit countless bugs and lost two days of my life and learned nothing except that Ceph is a beast. It felt like joining a backend team trying to set up the E2E test environment using a wiki two years out of date.

Installing MinIO was so much simpler that I became even more pissed at Ceph. In 10 minutes I copied their [installation guide](https://min.io/docs/minio/linux/operations/install-deploy-manage/deploy-minio-multi-node-multi-drive.html#minio-mnmd) into an [ansible playbook](./ansible/minio.yaml) and had it running across all the hosts. I then switched to running it in Nomad after creating and mounting the volume:

```yaml
# ansible-nomad var
nomad_host_volumes:
  - name: sata
    path: /mnt/sata
    owner: minio-user
    group: minio-user
    mode: "0755"
    read_only: false
```

```hcl
// tf/jobs/minio.hcl

job "minio" {
  datacenters = ["dc1"]
  type        = "system"

  group "minio" {
    volume "minio" {
      type      = "host"
      source    = "sata"
      read_only = false
    }
...
    task "minio" {
      driver = "docker"

      config {
        image        = "minio/minio:RELEASE.2023-08-16T20-17-30Z.hotfix.60799aeb0"
        network_mode = "host"
        ports        = ["minio-api", "minio-console"]
        args = ["server",
          "--address", ":${NOMAD_PORT_minio_api}",
          "--console-address", ":${NOMAD_PORT_minio_console}",
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
MINIO_VOLUMES = '{{ range service "consul" }}http://{{ .Address }}:9000/mnt/sata {{ end }}'
EOF
```

</details>
