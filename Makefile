define OP_RUN
  op run --env-file secrets.env --
endef

# helm
.PHONY: helm
helm: helm-ctx helm-metallb helm-headlamp helm-tailscale
	@helm upgrade homelab ./helm --values ./helm/values.yaml \
		--set "piholePassword=$(shell op read op://Private/pihole/password)"

helm-ctx:
	kubectx homelab

# https://metallb.universe.tf/installation/
# https://github.com/metallb/metallb/blob/main/charts/metallb/values.yaml
helm-metallb:
	helm repo add metallb https://metallb.github.io/metallb
	helm upgrade metallb metallb/metallb --namespace default

helm-headlamp:
	helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
	helm upgrade headlamp headlamp/headlamp --namespace kube-system \
		--set "service.type=NodePort" \
		--set "service.nodePort=30000"

helm-tailscale:
	helm repo add tailscale https://pkgs.tailscale.com/helmcharts
	@helm upgrade tailscale tailscale/tailscale-operator --force \
		--set "oauth.clientId=$(shell op read op://Private/homelab/tailscaleoauthkey)" \
		--set "oauth.clientSecret=$(shell op read op://Private/homelab/tailscaleoauthsecret)"

# ansible
.PHONY: ansible
ansible:
	$(OP_RUN) ansible-playbook -i ./ansible/hosts.yaml ./ansible/index.yaml

ansible/deps:
	ansible-galaxy collection install ansible.utils

# this seems really weird
ansible/upgrade-roles:
	$(OP_RUN) ansible-galaxy role install -r ./ansible/roles/requirements.yaml --force -p ./ansible/roles

# this also upgrades to the latest release version of k3s
ansible/k3s:
	$(OP_RUN) ansible-playbook -i ./ansible/hosts.yaml ./ansible/tasks/k3s.yaml

ansible/logrotate:
	$(OP_RUN) ansible-playbook -i ./ansible/hosts.yaml ./ansible/tasks/logrotate.yaml
