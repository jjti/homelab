# Homelab

## Nomad

I use Nomad to orchestrate/deploy the rest of the services. I created an [Ansible playbook](./ansible/nomad.yaml) based on [the Nomad deployment guide](https://developer.hashicorp.com/nomad/tutorials/enterprise/production-deployment-guide-vm-with-consul) that:

1. installs Nomad
1. creates a non-privileged group/user (nomad) to run the Nomad server
1. creates a data and config directory owned by nomad
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

## Traefik

I point the Cloudflare Tunnel at Traefik and use Traefik to route between the rest of the services in the homelab.
