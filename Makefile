define OP_RUN
  op run --env-file secrets.env --
endef

# ssh
.PHONY: ssh
ssh:
	sshuttle -NHr homelab 0/0

# ansible
.PHONY: ansible
ansible:
	$(OP_RUN) ansible-playbook -i ./ansible/hosts.yaml ./ansible/index.yaml

# this seems really weird
ansible/upgrade-roles:
	$(OP_RUN) ansible-galaxy role install -r ./ansible/roles/requirements.yaml --force -p ./ansible/roles

ansible/consul:
	$(OP_RUN) ansible-playbook -i ./ansible/hosts.yaml ./ansible/tasks/consul.yaml

ansible/nomad:
	$(OP_RUN) ansible-playbook -i ./ansible/hosts.yaml ./ansible/tasks/nomad.yaml

# hcl
hcl/fix:
	go run github.com/hashicorp/hcl/v2/cmd/hclfmt@latest -w ./nomad/*

# tf
.PHONY: tf
tf: tf/fix hcl/fix
	$(OP_RUN) terraform -chdir=./terraform apply -auto-approve -parallelism=30

tf/init:
	$(OP_RUN) terraform -chdir=./terraform init

tf/fix:
	terraform fmt -recursive .
