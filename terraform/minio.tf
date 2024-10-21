resource "random_password" "minio" {
  length  = 18
  special = false
}

resource "helm_release" "minio" {
  name = "minio"

  repository = "https://charts.min.io/"
  chart      = "minio"
  wait       = true

  # https://github.com/minio/minio/blob/master/helm/minio/values.yaml
  values = [<<EOF
image:
  tag: RELEASE.2024-10-13T13-34-11Z

extraArgs:
  - "--json"

environment:
  MINIO_BROWSER_LOGIN_ANIMATION: "off"

replicas: 3

rootUser: minio
rootPassword: ${var.minio_admin_password}

persistence:
  enabled: true
  storageClass: "local-storage"
  size: 1.78Ti

securityContext:
  enabled: true
  runAsUser: 0
  runAsGroup: 2
  fsGroup: 2

resources:
  requests:
    memory: 8Gi

users:
  - accessKey: ${var.minio_access_key}
    secretKey: ${var.minio_secret_key}
    policy: readwrite

EOF
  ]
}
