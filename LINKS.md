# Links

| Service   | URL                            |
| --------- | ------------------------------ |
| Headlamp  | http://192.168.0.130/headlamp/ |
| MinIO     | http://192.168.0.137:9001      |
| New Relic | https://one.newrelic.com/      |

## Services

Useful API docs: https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.31/#servicespec-v1-core

### Headlamp

```bash
kubectl get secret headlamp-admin -o jsonpath={".data.token"} | base64 -d
```

### MinIO

```bash
kubectl port-forward service/minio-console 9001:9001
```
