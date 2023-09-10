# Homelab

## Links

Nomad: http://192.168.0.172/admin/nomad
Traefik: http://192.168.0.172:8080

## Tools

### 1Password

### Terraform

### Ansible

## Nomad

I use Nomad to orchestrate/deploy the rest of the services. I created an [Ansible playbook](./ansible/nomad.yaml) based on [the Nomad deployment guide](https://developer.hashicorp.com/nomad/tutorials/enterprise/production-deployment-guide-vm-with-consul) that:

1. installs Nomad
1. creates a configuration file and data directory
1. starts the process

I then bootstrapped the ACL system, stored the management token to 1Password, and used Terraform to create a role and token with auth for the [jobs/deployments/allocations/evaluations APIs](https://developer.hashicorp.com/nomad/tutorials/access-control/access-control-policies#namespace-rules):

```hcl
resource "nomad_acl_policy" "read" {
  name        = "read"

  rules_hcl = <<EOT
namespace "default" {
  policy = "read"
}
EOT
}

resource "nomad_acl_token" "read" {
  name     = "client"
  type     = "client"
  policies = [nomad_acl_policy.read.name]
}
```

- [Nomad Production deployment guide](https://developer.hashicorp.com/nomad/tutorials/enterprise/production-deployment-guide-vm-with-consul)
- [Bootstrap Nomad ACL System](https://developer.hashicorp.com/nomad/tutorials/access-control/access-control-bootstrap)
- [Nomad ACL policies](https://developer.hashicorp.com/nomad/tutorials/access-control/access-control-policies)
- [note: you cannot run Nomad clients w/o root with cgroup v2](https://github.com/hashicorp/nomad/issues/17816)

## Traefik

I point the Cloudflare Tunnel at Traefik and use Traefik to route between the rest of the services in the homelab using Nomad's built in service discovery. I create one allocation of Traefik on each node using a [system type job](https://developer.hashicorp.com/nomad/docs/job-specification/job#type):

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
