define OP_RUN
  op run --env-file secrets.env --
endef

# tf
.PHONY: tf
tf: tf/fix
	$(OP_RUN) terraform -chdir=./terraform apply -auto-approve -parallelism=30

tf/init:
	$(OP_RUN) terraform -chdir=./terraform init -upgrade

tf/state:
	$(OP_RUN) terraform -chdir=./terraform state list

tf/fix:
	terraform fmt -recursive .

# ansible
.PHONY: ansible
ansible:
	$(OP_RUN) ansible-playbook -i ./ansible/hosts.yaml ./ansible/index.yaml

ansible/deps:
	ansible-galaxy collection install ansible.utils

# this seems really weird
ansible/upgrade-roles:
	$(OP_RUN) ansible-galaxy role install -r ./ansible/roles/requirements.yaml --force -p ./ansible/roles

ansible/k3s:
	$(OP_RUN) ansible-playbook -i ./ansible/hosts.yaml ./ansible/tasks/k3s.yaml

ansible/logrotate:
	$(OP_RUN) ansible-playbook -i ./ansible/hosts.yaml ./ansible/tasks/logrotate.yaml
