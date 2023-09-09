# Homelab

## Links

Nomad: http://192.168.0.172:4646
Traefik: http://192.168.0.172:8080

## Nomad

I use Nomad to orchestrate/deploy the rest of the services. I created an [Ansible playbook](./ansible/nomad.yaml) based on [the Nomad deployment guide](https://developer.hashicorp.com/nomad/tutorials/enterprise/production-deployment-guide-vm-with-consul) that:

1. installs Nomad
1. creates a configuration file and data directory
1. starts the process

I then bootstrapped the ACL system, stored the management token to 1Password, and used Terraform to create a role and token with auth only for the [jobs/deployments/allocations/evaluations APIs](https://developer.hashicorp.com/nomad/tutorials/access-control/access-control-policies#namespace-rules):

```hcl
resource "nomad_acl_policy" "default" {
  name        = "default"

  rules_hcl = <<EOT
namespace "default" {
  policy = "write"
}
EOT
}

resource "nomad_acl_token" "token" {
  name     = "client"
  type     = "client"
  policies = [nomad_acl_policy.default.name]
}
```

- [Nomad Production deployment guide](https://developer.hashicorp.com/nomad/tutorials/enterprise/production-deployment-guide-vm-with-consul)
- [Bootstrap Nomad ACL System](https://developer.hashicorp.com/nomad/tutorials/access-control/access-control-bootstrap)
- [Nomad ACL policies](https://developer.hashicorp.com/nomad/tutorials/access-control/access-control-policies)
- [note: you cannot run Nomad clients w/o root with cgroup v2](https://github.com/hashicorp/nomad/issues/17816)

## Traefik

I point the Cloudflare Tunnel at Traefik and use Traefik to route between the rest of the services in the homelab using Nomad's built in service discovery.

I spread allocations of the Traefik service across all the servers with:

```hcl
// jobs/traefik.hcl
job "traefik" {
    datacenters = ["dc1"]

    spread {
        attribute = node.datacenter
        weight    = 100
    }

    group "traefik" {
        count = 3
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
                ports = ["admin", "http"]
                args = [
...
                    # https://doc.traefik.io/traefik/providers/nomad/
                    "--providers.nomad=true",
                    "--providers.nomad.endpoint.address=http://localhost:4646",
                    "--providers.nomad.endpoint.token=${var.nomad_token}",
                ]
            }
        }
    }
}
```

- [Traefik Proxy Now Fully Integrates with Hashicorp Nomad](https://traefik.io/blog/traefik-proxy-fully-integrates-with-hashicorp-nomad/)
