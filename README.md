# Homelab

## Consul

Consul gets deployed using the [`ansible-consul` role](https://github.com/ansible-community/ansible-consul):

```bash
cd ./ansible/roles/ansible-consul/files
ansible-galaxy install -r ../requirements.yml
consul tls ca create
consul tls cert create -server -dc dc1 -domain consul
cd -

ansible-playbook -i hosts.yaml ./tasks/consul.yaml
```

`ansible-consul` with the `vars` in [`ansible/consul.yaml`](ansible/consul.yaml) gets configured with TLS, gossip encryption, ACLs, and Prometheus metrics.

- [ansible-consul](https://github.com/ansible-community/ansible-consul)
- [Consul production checklist](https://developer.hashicorp.com/consul/tutorials/production-deploy/production-checklist)

## Nomad

Nomad orchestrates and deploys the rest of the services. At first I wrote my own playbook. But then I found `ansible-nomad` which -- while a bit out of date -- is way better: https://github.com/ansible-community/ansible-nomad

```bash
ansible-playbook -i hosts.yaml ./tasks/nomad.yaml
```

### Docs

- [ansible-nomad](https://github.com/ansible-community/ansible-nomad)
- [Bootstrap Nomad ACL System](https://developer.hashicorp.com/nomad/tutorials/access-control/access-control-bootstrap)
- [Nomad ACL policies](https://developer.hashicorp.com/nomad/tutorials/access-control/access-control-policies)

### PITA Bug from Beelink Product ID

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

## Traefik

Cloudflare Tunnels point at Traefik and use Traefik to route between the rest of the services in the homelab using Nomad's built in service discovery. I create one allocation of Traefik on each node using a [system type job](https://developer.hashicorp.com/nomad/docs/job-specification/job#type):

```hcl
// jobs/traefik.hcl
job "traefik" {
    datacenters = ["dc1"]
    type        = "system

    group "traefik" {
...
```

And configure Traefik to get service instances from Nomad with a read-only token created in TF:

```hcl
// tf/nomad.tf
resource "nomad_variable" "traefik" {
  path = "nomad/jobs/traefik"
  items = {
    read_token = data.consul_acl_token_secret_id.traefik.secret_id
  }

// jobs/traefik.hcl
      config {
        image        = "traefik:2.10"
        network_mode = "host"
        ports        = ["http", "admin"]
        volumes      = ["local/traefik.yaml:/etc/traefik/traefik.yaml"]
      }

      template {
        # https://developer.hashicorp.com/nomad/tutorials/load-balancing/load-balancing-traefik
        data = <<EOF
providers:
  consulCatalog:
    endpoint:
      address: {{ env "NOMAD_IP_http" }}:8500
      scheme: http
      token: {{ with nomadVar "nomad/jobs/traefik" }}{{ .read_token }}{{ end }}
```

## Cloudflare Tunnel

I want to dispatch Nomad jobs from Github Actions. I opted for a Cloudflare Tunnel.

I did not go with [Tailscale Funnels](https://tailscale.com/kb/1247/funnel-serve-use-cases/) or Ngrok because Cloudflare has some extra nice-to-have features like domain management, access policies w/ IDPs, etc.

Each node runs `cloudflared` for a `cloudflare_tunnel` created with Terraform. The `cloudflared` process points at the Nomad endpoint on each host.

```hcl
// creating a tunnel with a secret
resource "cloudflare_tunnel" "auto_tunnel" {
  name       = "homelab"
  secret     = random_id.tunnel_secret.b64_std
}

// configuring egress to proxy to nomad
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

To restrict access I created an access service token, attached it to an access policy associated w/ the domain so I can call into the homelab from Github Actions:

```bash
curl -H "CF-Access-Client-Id: xx" -H "CF-Access-Client-Secret: xx" -v https://homelab.example.com
```

- [Cloudflare Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)

## MinIO

I tried really hard to make Ceph work. I wanted both a distributed filesystem plus an S3-compatible API. I tried `cephadm`, `ceph-ansible`, hoping from node to node running `systemctl restart ceph-mon...`. I hit countless bugs and lost two days of my life and learned nothing except that Ceph is a beast. It felt like joining a backend team trying to set up the E2E test environment using a wiki two years out of date.

Installing MinIO was so much simpler to install that it made me even more pissed at Ceph. In 10 minutes I copied their [installation guide](https://min.io/docs/minio/linux/operations/install-deploy-manage/deploy-minio-multi-node-multi-drive.html#minio-mnmd) into an [ansible playbook](./ansible/minio.yaml) and had it running across all the hosts. I then switched to running it in Nomad after creating an mounting the volume:

```yaml
# ansible
nomad_host_volumes:
  - name: sata
    path: /mnt/sata
    owner: minio-user
    group: minio-user
    mode: "0755"
    read_only: false
```

```hcl
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
          "http://192.168.0.13{7...9}:${NOMAD_PORT_minio_api}/mnt/sata", # cheating w/ the ips here
        ]
      }

      volume_mount {
        volume           = "minio"
        destination      = "/mnt/sata"
        propagation_mode = "private"
      }
```
