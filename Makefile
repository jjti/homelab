# ssh
.PHONY: ssh
ssh:
	sshuttle -NHr homelab 0/0

# ansible
.PHONY: ansible
ansible:
	ansible-playbook -i ./ansible/hosts.yaml ./ansible/index.yaml

# this seems really weird
ansible/upgrade-roles:
	ansible-galaxy role install -r ./ansible/roles/requirements.yaml --force -p ./ansible/roles

ansible/consul:
	ansible-playbook -i ./ansible/hosts.yaml ./ansible/tasks/consul.yaml

ansible/nomad:
	ansible-playbook -i ./ansible/hosts.yaml ./ansible/tasks/nomad.yaml

# docker
.PHONY: docker
docker:
	docker login -u jjtimmons -p '${DOCKER_PASSWORD}' docker.io
	docker build ./docker/otel -t jjtimmons/otel:latest
	docker push jjtimmons/otel:latest

# hcl
hcl/fix:
	go run github.com/hashicorp/hcl/v2/cmd/hclfmt@latest -w ./nomad/*

# tf
.PHONY: tf
tf: tf/fix hcl/fix
	cd terraform && terraform apply -auto-approve -parallelism=30

tf/init:
	cd terraform && terraform init

tf/fix:
	terraform fmt -recursive .
