# ssh
.PHONY: ssh
ssh:
	sshuttle -NHr homelab 0/0

# ansible
.PHONY: ansible
ansible:
	@ansible-playbook -i ./ansible/hosts.yaml ./ansible/index.yaml

ansible/consul:
	@ansible-playbook -i ./ansible/hosts.yaml ./ansible/consul.yaml

ansible/nomad:
	@ansible-playbook -i ./ansible/hosts.yaml ./ansible/nomad.yaml

# hcl
hcl/fix:
	@go run github.com/hashicorp/hcl/v2/cmd/hclfmt@latest -w ./nomad/*

# tf
.PHONY: tf
tf: tf/fix hcl/fix
	@cd tf && terraform apply -auto-approve -parallelism=30

tf/init:
	@cd tf && terraform init

tf/fix:
	@terraform fmt -recursive .
