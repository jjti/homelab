# Links

| Service   | URL                          | Pwd                                                     |
| --------- | ---------------------------- | ------------------------------------------------------- |
| Headlamp  | http://192.168.0.137:30000   | `kubectl create token headlamp --namespace kube-system` |
| Pi-hole   | http://192.168.0.201/admin/  | `op read op://Private/pihole/password`                  |
| MinIO     | http://192.168.0.204         |
| Jellyfin  | http://192.168.0.200         |
| Jellyseer | http://192.168.0.203         |
| Sonarr    | http://192.168.0.137/sonarr  |
| Radarr    | http://192.168.0.137/radarr  |
| Sabnzdb   | http://192.168.0.137/sabnzbd |                                                         |

## K8s context

```bash
kubectx homelab
kubens default
```

## Services

Useful API docs: https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#servicespec-v1-core
