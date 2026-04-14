.PHONY: bootstrap-prereqs init plan apply destroy fmt validate docs help

BOOTSTRAP_DIR := bootstrap
ENV ?= prod

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

bootstrap-prereqs: ## Run the one-time Azure CLI bootstrap script (requires az login as Global Admin)
	@echo "Running pre-Terraform bootstrap..."
	chmod +x scripts/bootstrap.sh
	scripts/bootstrap.sh

init: ## Initialize Terraform backend for bootstrap root
	terraform -chdir=$(BOOTSTRAP_DIR) init

plan: ## Run terraform plan for bootstrap root
	terraform -chdir=$(BOOTSTRAP_DIR) plan -out=tfplan

apply: ## Run terraform apply for bootstrap root (uses saved plan)
	terraform -chdir=$(BOOTSTRAP_DIR) apply tfplan

destroy: ## Destroy all bootstrap-managed resources (use with caution)
	terraform -chdir=$(BOOTSTRAP_DIR) destroy

init-env: ## Initialize a landing zone environment: make init-env ENV=prod
	terraform -chdir=environments/$(ENV) init

plan-env: ## Plan a landing zone environment: make plan-env ENV=prod
	terraform -chdir=environments/$(ENV) plan -out=tfplan

apply-env: ## Apply a landing zone environment: make apply-env ENV=prod
	terraform -chdir=environments/$(ENV) apply tfplan

fmt: ## Format all Terraform files
	terraform fmt -recursive .

validate: ## Validate all Terraform configurations
	terraform -chdir=$(BOOTSTRAP_DIR) validate
	terraform -chdir=environments/prod validate
	terraform -chdir=environments/nonprod validate

docs: ## Generate module documentation (requires terraform-docs)
	terraform-docs markdown table --output-file README.md modules/management-groups/
	terraform-docs markdown table --output-file README.md modules/policy/
	terraform-docs markdown table --output-file README.md modules/rbac/
	terraform-docs markdown table --output-file README.md modules/logging/
	terraform-docs markdown table --output-file README.md modules/budget/
