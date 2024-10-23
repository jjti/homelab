# https://registry.terraform.io/providers/alekc/kubectl/latest/docs/data-sources/kubectl_path_documents
data "kubectl_path_documents" "documents" {
  pattern = "../kubernetes/manifests/*.yaml"
  vars = {
    minio_admin_password = var.minio_admin_password
    minio_access_key     = var.minio_access_key
    minio_secret_key     = var.minio_secret_key
    nodes                = "ser5-1,ser5-2,ser5-3"
  }
}

resource "kubectl_manifest" "manifests" {
  for_each  = data.kubectl_path_documents.documents.manifests
  yaml_body = each.value
}
