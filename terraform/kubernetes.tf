# https://registry.terraform.io/providers/alekc/kubectl/latest/docs/data-sources/kubectl_path_documents
data "kubectl_path_documents" "documents" {
  pattern = "../kubernetes/manifests/*.yaml"
  vars = {
    minio_access_key       = var.minio_access_key
    minio_admin_password   = var.minio_admin_password
    minio_secret_key       = var.minio_secret_key
    nodes                  = "ser5-1,ser5-2,ser5-3"
    arr_volumes            = "sonarr,radarr,bazarr,sabnzbd,jellyseer,jellyfin"
    tailscale_oauth_key    = var.tailscale_oauth_key
    tailscale_oauth_secret = var.tailscale_oauth_secret
  }
}

resource "kubectl_manifest" "manifests" {
  for_each  = data.kubectl_path_documents.documents.manifests
  yaml_body = each.value
}
