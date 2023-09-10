# ansible
.PHONY: ansible
ansible:
	@ansible-playbook -i ./ansible/inventory.yaml ./ansible/playbook.yaml

# hcl
hcl/fix:
	@go run github.com/hashicorp/hcl/v2/cmd/hclfmt@latest -w ./tf/jobs/*

# tf
.PHONY: tf
tf: tf/fix
	@cd tf && terraform init && terraform apply -auto-approve

tf/fix:
	@terraform fmt -recursive .