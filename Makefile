SHELL := /bin/bash
AWS_REGION ?= eu-north-1
CLUSTER_NAME ?= storefront-eks

.PHONY: help up down url status validate port-forward

help: ## Show available demo and operations commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'

up: ## Spin up EKS, install ArgoCD, deploy storefront-api, and trigger CI
	@echo "==> 1/4 Provisioning AWS VPC, ECR, and EKS via Terraform..."
	cd terraform && terraform init -input=false && terraform apply -auto-approve
	@echo "==> 2/4 Updating local kubeconfig..."
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME)
	@echo "==> 3/4 Installing ArgoCD (v2.13.3)..."
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.13.3/manifests/install.yaml
	kubectl rollout status deployment/argocd-server -n argocd --timeout=180s
	kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=180s
	@echo "==> 4/4 Registering storefront-api-test ArgoCD Application & triggering CI..."
	kubectl apply -f argocd/application-test.yaml
	-gh workflow run ci.yaml --repo Bsalarian/storefront-api 2>/dev/null || echo "Trigger CI manually in storefront-api if gh CLI is not authenticated."
	@echo "==> Bootstrap complete. Run 'make url' in ~60s to get your public demo link."

down: ## Cleanly remove K8s LoadBalancers and destroy all AWS resources
	@echo "==> 1/2 Deleting Kubernetes namespaces to release AWS LoadBalancers..."
	-kubectl delete application storefront-api-test -n argocd --ignore-not-found=true
	-kubectl delete namespace storefront-test argocd --ignore-not-found=true --timeout=120s
	@echo "==> 2/2 Destroying Terraform-managed AWS infrastructure..."
	cd terraform && terraform destroy -auto-approve
	@echo "==> All AWS resources destroyed. Billing stopped."I manually in storefront-api if gh CLI is not authenticated."

url: ## Print the clickable public LoadBalancer URL for the interviewer
	@HOST=$$(kubectl get svc storefront-api -n storefront-test -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null); \
	if [ -z "$$HOST" ]; then \
		echo "LoadBalancer is still provisioning (or cluster is down). Run 'kubectl describe svc storefront-api -n storefront-test' to check."; \
	else \
		echo "Live Demo URL: http://$$HOST/"; \
		echo "Health Check:  http://$$HOST/health"; \
		echo "Metrics:       http://$$HOST/metrics"; \
	fi

status: ## Check ArgoCD sync status, pods, and service IP
	kubectl get applications -n argocd
	kubectl get pods,svc -n storefront-test

validate: ## Validate Kustomize rendering for test and production overlays
	kubectl kustomize deploy/overlays/test > /dev/null
	kubectl kustomize deploy/overlays/production > /dev/null
	@echo "Kustomize overlays valid."

port-forward: ## Tunnel localhost:8080 directly to the cluster Service
	kubectl port-forward svc/storefront-api -n storefront-test 8080:80
