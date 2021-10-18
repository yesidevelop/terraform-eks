AWS_PROFILE=default

kubeconfig:
	KUBECONFIG=./kubeconfig aws --profile $(AWS_PROFILE) eks update-kubeconfig --name eks

apply:
	terraform init -get -upgrade && terraform get -update && terraform apply