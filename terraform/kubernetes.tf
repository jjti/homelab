resource "kubernetes_manifest" "resources" {
  for_each = fileset(path.module, "../kubernetes/*")

  manifest = yamldecode(file("${path.module}/${each.key}"))
}

resource "helm_release" "headlamp" {
  name = "headlamp"

  repository = "https://headlamp-k8s.github.io/headlamp/"
  chart      = "headlamp"
}
