# Homelab

## Hardware

<img width="500px" src="https://github.com/jjti/homelab/assets/13923102/6a97ead1-d26e-4056-8fbc-c2fc2da03fb1" />

The homelab is made up of three [Beelink Mini SER5 Maxes](https://www.bee-link.com/beelink-amd-ryzen-5-ser5-5800u-minip-26183466). Each has 32 GB DDR4 of memory and 500 GB of NVMe storage. I also added [2 TB of SSD storage to each](https://www.amazon.com/dp/B07YD5F561). So in total there's:

- 24 cores / 48 threads
- 96 GB memory
- 1.5 TB NVMe storage and 6 TB SATA storage

The main reason I opt'ed the SER5 Max was they're cheap (~$350 each), have low power draw (advertised at 54 W per node), and they don't take up much space. That said, everything is slower in these compared to a consumer desktop: the 5800H is a laptop CPU, storage is over PCIe 3 not 4, and it's DDR4 memory. That's all fine though since this is to tinker.

## Deployment

### Terraform

I use Nomad job specs created in Terraform with the [`nomad_job` resource](https://registry.terraform.io/providers/hashicorp/nomad/latest/docs/resources/job) to deploy applications into the homelab. Secrets are populated from 1Password.

```bash
# deploy job specs to Nomad, configure Cloudflare, etc
make tf
```

```hcl
# tf/nomad.tf
resource "nomad_job" "jobs" {
  for_each = fileset(path.module, "../nomad/*")

  jobspec = file("${path.module}/${each.key}")
}
```

### Consul

Consul is used as a service catalog -- to configure Traefik -- and to bootstrap Nomad.

- [ansible-consul](https://github.com/ansible-community/ansible-consul)
- [Consul production checklist](https://developer.hashicorp.com/consul/tutorials/production-deploy/production-checklist)

<details>

<summary>ansible-consul</summary>

I deployed it using the [`ansible-consul` role](https://github.com/ansible-community/ansible-consul).

Compared to deploying Consul manually, `ansible-consul` has more knobs, sanity checks, and baked-in best practices. It's also nice for setting things up once, then automating away the tedious part of SSH'ing into every host. But `ansible-consul` is also very stale and the defaults are for development Consul clients. I've changed a couple dozen settings in [./ansible/tasks/consul.yaml](./ansible/consul.yaml) to enable TLS, gossip encryption, ACLs, and prometheus metrics.

```bash
cd ./ansible/roles/ansible-consul/files
ansible-galaxy install -r ../requirements.yml
consul tls ca create
consul tls cert create -server -dc dc1 -domain consul
cd -

ansible-playbook -i hosts.yaml ./tasks/consul.yaml
```

</details>

### Nomad

Nomad orchestrates and deploys the rest of the services (besides itself and Consul). When I was deploying it I first wrote an Ansible playbook. But then I found `ansible-nomad`: https://github.com/ansible-community/ansible-nomad.

```bash
ansible-playbook -i hosts.yaml ./tasks/nomad.yaml
```

- [ansible-nomad](https://github.com/ansible-community/ansible-nomad)
- [Bootstrap Nomad ACL System](https://developer.hashicorp.com/nomad/tutorials/access-control/access-control-bootstrap)
- [Nomad ACL policies](https://developer.hashicorp.com/nomad/tutorials/access-control/access-control-policies)

<details>

<summary>PITA bug from Beelink Product ID</summary>

While setting up Nomad I hit an annoying bug where 2 of 3 clients were unable to register themselves:

```txt
client.rpc: error performing RPC to server: error="rpc error: rpc error: node secret ID does not match. Not registering node." rpc=Node.Register server=192.168.0.138:46>
client.rpc: error performing RPC to server which is not safe to automatically retry: error="rpc error: rpc error: node secret ID does not match. Not registering node." >
```

I spent 3-4 hours re-reading the same bug reports ([1](https://discuss.hashicorp.com/t/nomad-0-11-1-client-error-node-secret-id-does-not-match/8568), [2](https://github.com/hashicorp/nomad/issues/2550), [3](https://github.com/hashicorp/nomad/issues/1928)) and purging + reinstalling Nomad. I got lucky and eventually noticed that the client ids (not secret ids; which I'd checked) were identical between clients:

```txt
# host 1
client: started client: node_id=9466df29-582e-42cf-84dc-296acd1886c9
# host 2
client: started client: node_id=9466df29-582e-42cf-84dc-296acd1886c9
```

I worked around the issue by setting random client IDs via ansible (below) and they all came up fine:

```yaml
- name: Generate lowercase UUID using Python
  command: python3 -c "import uuid; print(str(uuid.uuid4()).lower())"
  register: generated_uuid

- name: Save the UUID to /var/nomad/client/client-id
  copy:
    content: "{{ generated_uuid.stdout }}"
    dest: /var/nomad/client/client-id
  when: not client_id_file.stat.exists
```

Curious why I was getting duplicates, I found that Nomad uses a [host-level UUID retrieved](https://github.com/shirou/gopsutil/blob/c806740b348abc3b0a5abb0aa181cf1982b7acc4/host/host_linux.go#L38) from `/sys/class/dmi/id/product_uuid` which is frequently -- and in my case -- bogus. My UUIDs across all machines was whatever hard-coded UUID Beelink had set, so all my node were starting with identical node IDs:

```txt
# host 1
root@ser5-1:/home/josh# cat /sys/class/dmi/id/product_uuid
03000200-0400-0500-0006-000700080009
# host 2
root@ser5-2:/home/josh# cat /sys/class/dmi/id/product_uuid
03000200-0400-0500-0006-000700080009
```

This is still weird though because Nomad defaults to generating a unique `client-id` [randomly on start-up](https://github.com/hashicorp/nomad/blob/3534307d0d3a9979318182d212930b637cc4d483/client/client.go#L1408) when `no_host_uuid` is false (which is [`true` by default and v1.6.1](https://developer.hashicorp.com/nomad/docs/configuration/client#no_host_uuid) which is what I was running):

```go
	hostInfo, err := host.Info()
	if !conf.NoHostUUID && err == nil {
		if hashed, ok := helper.HashUUID(hostInfo.HostID); ok {
			hostID = hashed
		}
	}
```

Unfortunately for me, ansible-nomad is stale and has [`nomad_no_host_uuid: no` as a default](https://github.com/ansible-community/ansible-nomad#nomad_no_host_uuid). I thought I worked around that by setting it to `yes` during one of the reinstalls, but I didn't delete the stale `/var/nomad/client/client-id` file so they stuck around.

</details>

## Access

There's two types of accessibility for the homelab:

1. HTTP API access to services and Nomad
2. SSH access to the homelab nodes

I used [Cloudflare Tunnels](#cloudflare-tunnel) for address both. I create one egress configuration rule pointing at Traefik (for HTTP access to hosted APIs) and another pointing at the SSH server for remote access to Nomad, Consul, etc. I use `sshuttle` to get remote access to the result of services in the homelab.

### Traefik

Traefik routes to the services using Consul's catalog for service discovery.

I haven't spent the time to wire _all_ the services into Traefik (yet). It's tricky with services like Nomad because you can't configure the path the UI queries: ([eg Github thread for Nomad](https://github.com/hashicorp/nomad/issues/4479)). So even if I put Nomad behind `/nomad` in Traefik the UI will blissfully query the (default) `/ui` path that 404s.

I also haven't spent the time moving everything into a service mesh. I should -- it would be nice to offload mTLS and intentions to Consul -- but I ran into a issue trying to join all the MinIO instances into a cluster (see: [MINIO_VOLUMES](https://min.io/docs/minio/linux/reference/minio-server/minio-server.html#envvar.MINIO_VOLUMES)). In theory I could use a [Nomad template that interpolates Consul `minio` service instances](https://developer.hashicorp.com/nomad/docs/job-specification/template#consul-services) but found it creates a chicken or the egg issue where MinIO won't start without `MINIO_VOLUMES` so then there's nothing to populate the `minio` service in Consul and fill the template. I've since found this `{{ service "web|any" }}` filter that should return all instances, health or otherwise, but I began to prefer to using `static = $port` and `host` networking since it's faster.

<details>

<summary>Traefik configuration</summary>

I create one allocation of Traefik on each node using a [system type job](https://developer.hashicorp.com/nomad/docs/job-specification/job#type). And create a read-only Consul token that I pass to Traefik through a Nomad Variable:

```hcl
// tf/nomad.tf
resource "nomad_variable" "traefik" {
  path = "nomad/jobs/traefik"
  items = {
    read_token = data.consul_acl_token_secret_id.traefik.secret_id
  }
}

// jobs/traefik.hcl
job "traefik" {
    datacenters = ["dc1"]
    type        = "system

    group "traefik" {
...

      config {
        image        = "traefik:2.10"
        network_mode = "host"
        ports        = ["http", "admin"]
        volumes      = ["local/traefik.yaml:/etc/traefik/traefik.yaml"]
      }

      template {
        # https://developer.hashicorp.com/nomad/tutorials/load-balancing/load-balancing-traefik
        destination = "local/traefik.yaml"
        data        = <<EOF
...
providers:
  consulCatalog:
    exposedByDefault: false
    connectAware: true
    cache: false
    connectByDefault: false

    endpoint:
      address: {{ env "NOMAD_IP_http" }}:8500
      scheme: http
      token: {{ with nomadVar "nomad/jobs/traefik" }}{{ .read_token }}{{ end }}
```

</details>

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

<summary>sshuttle config</summary>

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
<summary>MinIO config</summary>

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
