# ansible
.PHONY: ansible
ansible:
	ansible-playbook -i ./ansible/inventory.yaml ./ansible/setup.yaml

# tf
.PHONY: tf
tf:
	cd tf && terraform init && terraform apply

tf/fix:
	@terraform fmt -recursive .