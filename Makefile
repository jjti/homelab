# ansible
.PHONY: ansible
ansible:
	ansible-playbook -i ./ansible/inventory.yaml ./ansible/playbook.yaml

# tf
.PHONY: tf
tf:
	cd tf && terraform init && terraform apply -auto-approve

tf/fix:
	@terraform fmt -recursive .