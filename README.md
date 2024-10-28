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

Tailscale. TODO: more details. For the homelab use-case it's better than Cloudflare Tunnels and sshuttle.

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
