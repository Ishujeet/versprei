
# Image URL to use all building/pushing image targets
IMG ?= versprei:latest
KUBE_NAMESPACE ?= default
# Setting SHELL to bash allows bash commands to be executed by recipes.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)


# Build the Docker image
docker-build:
    docker build -t $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG) .

# Push the Docker image to a container registry (change the registry URL as needed)
docker-push:
    docker push $(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)

# Apply the RBAC configurations
rbac-apply:
    kubectl apply -f config/rbac/ -n $(KUBE_NAMESPACE)

# Apply the Custom Resource Definitions (CRDs)
crds-apply:
    kubectl apply -f config/crd/ -n $(KUBE_NAMESPACE)

# Apply the Mutating Webhook Configuration
webhook-apply:
	kubectl apply -f config/webhook/ -n $(KUBE_NAMESPACE)

# Apply the Kubernetes deployment
kube-apply:
    kubectl apply -f config/deploy/ -n $(KUBE_NAMESPACE)

# Delete the Kubernetes deployment
kube-delete:
    kubectl delete -f config/deploy/ -n $(KUBE_NAMESPACE)

# Build the Docker image, push it to the registry, and apply RBAC, CRDs, Mutating Webhook, and the Kubernetes deployment
install: docker-build docker-push rbac-apply crds-apply kube-apply webhook-apply 

# Redeploy the webhook service after making changes
redeploy: docker-build docker-push
	kubectl restart deploy versprei-webhook-service -n $(KUBE_NAMESPACE)

# Test the webhook using a sample app deployment
test:
	kubectl apply -f config/samples/ -n $(KUBE_NAMESPACE)

# Clean up (delete) the Kubernetes deployment, RBAC, CRDs, and the Docker image from the local machine
clean:
    kubectl delete deployment config/deploy/ -n $(KUBE_NAMESPACE) --ignore-not-found=true
    kubectl delete -f config/rbac/ -n $(KUBE_NAMESPACE) --ignore-not-found=true
    kubectl delete -f config/crd/ -n $(KUBE_NAMESPACE) --ignore-not-found=true
	kubectl delete -f config/samples/ -n $(KUBE_NAMESPACE) --ignore-not-found=true
	kubectl delete -f config/webhook/ -n $(KUBE_NAMESPACE) --ignore-not-found=true
    docker rmi $(IMG) --force

.PHONY: docker-build docker-push rbac-apply crds-apply kube-apply webhook-apply kube-delete build-and-deploy clean