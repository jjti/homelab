default:
    @just --list

# Install ansible + 1password CLI on the mac, then ansible collections.
deps:
    brew install ansible 1password-cli
    ansible-galaxy collection install ansible.utils ansible.posix community.docker community.general

# Single-host docker setup on bazz (bazzite). Replaces the old k3s cluster.
bazz:
    OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES \
        ansible-playbook -i ./ansible/hosts.yaml ./ansible/tasks/bazz.yaml
