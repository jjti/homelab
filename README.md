# Homelab

## Links

- Consul: http://192.168.0.137:8500/consul/dc1/services
- Nomad: https://nomad.joshuatimmons.com
- Traefik: https://traefik.joshuatimmons.com
- Grafana: https://joshuatimmons.com/grafana/

## Tools

### 1Password

### Terraform

### Ansible

## Consul

I'm using Consul for service discovery, mTLS, and service intentions: https://developer.hashicorp.com/consul/docs/connect/connect-internals.

Consul gets deployed using the [`ansible-consul` role](https://github.com/ansible-community/ansible-consul):

```bash
cd ./ansible/roles/ansible-consul
ansible-galaxy install -r ./requirements.yml
python3 -m pip install -r ./requirements.txt

cd ./files
consul tls ca create
consul tls cert create -server -dc dc1 -domain consul
cd ../../..

ansible-playbook -i inventory.yaml ./consul.yaml
```

`ansible-consul` with the `vars` in [`ansible/consul.yaml`](ansible/consul.yaml) gets configured with TLS, gossip encryption, ACLs bootstrapped, and Prometheus metrics enabled.

- [ansible-consul](https://github.com/ansible-community/ansible-consul)
- [Consul production checklist](https://developer.hashicorp.com/consul/tutorials/production-deploy/production-checklist)

## Nomad

Nomad orchestrates and deploys the rest of the services. At first I wrote my own playbook. But then I found `ansible-nomad` which -- while a bit out of date -- is way better: https://github.com/ansible-community/ansible-nomad

```bash
ansible-playbook -i inventory.yaml ./nomad.yaml
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
resource "nomad_job" "traefik" {
  jobspec = file("${path.module}/jobs/traefik.hcl")

    hcl2 {
        vars = {
            nomad_token = nomad_acl_token.read.secret_id
        }
    }
}

// jobs/traefik.hcl
job "traefik" {
    group "traefik" {
        task "server" {
            driver = "docker"

            config {
                image = "traefik:2.10"
                network_mode = "host"
                ports = ["admin", "http"]
                args = [
...
                    # https://doc.traefik.io/traefik/providers/nomad/
                    "--providers.nomad=true",
                    "--providers.nomad.endpoint.address=http://${NOMAD_IP_http}:4646",
                    "--providers.nomad.endpoint.token=${var.nomad_token}",
                ]
            }
        }
    }
}
```

- [Traefik Proxy Now Fully Integrates with Hashicorp Nomad](https://traefik.io/blog/traefik-proxy-fully-integrates-with-hashicorp-nomad/)

## Cloudflare Tunnel

I want to dispatch Nomad jobs from Github Actions, check the Traefik dashboard from a coffee shop, etc. I opt'ed for Cloudflare Tunnels to expose my homelab to the internet.

I opted not to use [Tailscale Funnels](https://tailscale.com/kb/1247/funnel-serve-use-cases/) or Ngrok because Cloudflare has some extra nice-to-have features like domain management, access policies w/ IDPs, etc.

Each node runs `cloudflared` for a tunnel created with Terraform. The `cloudflared` processes point at the Traefik reverse proxies listening on port 80.

```hcl
resource "cloudflare_tunnel" "auto_tunnel" {
  name       = "homelab"
  secret     = random_id.tunnel_secret.b64_std
}

resource "cloudflare_tunnel_config" "auto_tunnel" {
  tunnel_id  = cloudflare_tunnel.auto_tunnel.id
  account_id = var.cloudflare_account_id

  config {
   ingress_rule {
     hostname = cloudflare_record.homelab.hostname
     service  = "http://localhost:80"
   }
  }
}
```

To restrict access I created an access service token, attached it to an access policy associated w/ the domain so I can call into the homelab from Github Actions:

```bash
curl -H "CF-Access-Client-Id: xx" -H "CF-Access-Client-Secret: xx" -v https://homelab.example.com
```

- [Cloudflare Tunnels](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)

## MinIO

I tried really hard to make Ceph work. I wanted both a distributed filesystem plus an S3-compatible API. I tried `cephadm`, `ceph-ansible`, hoping from node to node running `systemctl restart ceph-mon...`. I hit countless bugs and lost two days of my life and learned nothing except that Ceph is a beast. It felt like joining a backend team trying to set up the E2E test environment using a wiki two years out of date.

Installing MinIO was so much simpler to install that it made me even more pissed at Ceph. In 10 minutes I copied their (installation guide)[https://min.io/docs/minio/linux/operations/install-deploy-manage/deploy-minio-multi-node-multi-drive.html#minio-mnmd] into an [ansible playbook](./ansible/minio.yaml) and had it running across all the hosts.
