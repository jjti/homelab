# Links

First disable VPN, then:

| Service   | URL                                          |
| --------- | -------------------------------------------- |
| Headlamp  | kubectl port-forward $headlamp-pod 8080:4466 |
| Pi-hole   | http://pihole.com/admin/index.php            |
| MinIO     | http://minio.com                             |
| New Relic | https://one.newrelic.com/                    |
| Sonarr    | https://sonarr.com/                          |
| Radarr    | https://radarr.com/                          |
| Jellyfin  | https://stream.com/                          |
| Jellyseer | https://download.com/                        |

## K8s context

```bash
kubectx homelab
kubens default
```

## Services

Useful API docs: https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#servicespec-v1-core

### Headlamp

```bash
kubectl get secret headlamp-admin -o jsonpath={".data.token"} | base64 -d
```
