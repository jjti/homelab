default: bazz

# Initialize terraform (one-time, after cloning). Reads backend settings from
# terraform/backend.hcl (gitignored — copy from backend.hcl.example).
tf-init:
    cd terraform && terraform init -backend-config=backend.hcl

# Plan + apply the backup bucket + IAM user.
tf:
    cd terraform && terraform apply

# Print AWS creds for the backup IAM user (to paste into ~/.config/immich-backup.env on bazz).
tf-creds:
    @cd terraform && echo "RCLONE_CONFIG_S3_ACCESS_KEY_ID=$(terraform output -raw access_key_id)" && echo "RCLONE_CONFIG_S3_SECRET_ACCESS_KEY=$(terraform output -raw secret_access_key)"

# Install ansible + 1password CLI on the mac, then ansible collections.
deps:
    brew install ansible 1password-cli
    ansible-galaxy collection install ansible.utils ansible.posix community.docker community.general

# Single-host docker setup on bazz (bazzite). Replaces the old k3s cluster.
# -K prompts for the remote sudo password (needed for the host-side tailscale tasks).
bazz:
    OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES \
        ansible-playbook -i ./ansible/hosts.yaml ./ansible/tasks/bazz.yaml -K
