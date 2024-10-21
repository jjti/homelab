# Links

| Service   | URL                                           |
| --------- | --------------------------------------------- |
| Consul    | http://192.168.0.137:8500/consul/dc1/services |
| Traefik   | http://192.168.0.137:8080/dashboard           |
| MinIO     | http://192.168.0.137:9001                     |
| New Relic | https://one.newrelic.com/                     |

## Services

### Headlamp

```bash
kubectl port-forward service/headlamp 8080:80
```

```bash
kubectl get secret headlamp-admin -o jsonpath={".data.token"} | base64 -d
open http://localhost:8080
```

### Minio

```bash
kubectl port-forward service/minio-console 9001:9001
```
