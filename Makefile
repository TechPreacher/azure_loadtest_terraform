# Makefile for Azure Terraform deployment

# Default variables
SUBSCRIPTION_ID ?= 0b962213-fc84-4c8d-bc1a-2dce59741c5a

.PHONY: help login set-subscription init validate plan apply destroy

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

login: ## Login to Azure
	az login

set-subscription: ## Set the Azure subscription
	@if [ -z "$(SUBSCRIPTION_ID)" ]; then \
		echo "Error: SUBSCRIPTION_ID is required. Use 'make set-subscription SUBSCRIPTION_ID=your-subscription-id'"; \
		exit 1; \
	fi
	az account set --subscription $(SUBSCRIPTION_ID)

init: ## Initialize Terraform
	cd terraform && terraform init

validate: ## Validate Terraform configuration
	cd terraform && terraform validate

plan: ## Preview Terraform changes
	@if [ -z "$(SUBSCRIPTION_ID)" ]; then \
		echo "Error: SUBSCRIPTION_ID is required. Use 'make plan SUBSCRIPTION_ID=your-subscription-id'"; \
		exit 1; \
	fi
	az account set --subscription $(SUBSCRIPTION_ID) && \
	cd terraform && terraform plan -var="subscription_id=$(SUBSCRIPTION_ID)"

apply: ## Apply Terraform configuration
	@if [ -z "$(SUBSCRIPTION_ID)" ]; then \
		echo "Error: SUBSCRIPTION_ID is required. Use 'make apply SUBSCRIPTION_ID=your-subscription-id'"; \
		exit 1; \
	fi
	az account set --subscription $(SUBSCRIPTION_ID) && \
	cd terraform && terraform apply -var="subscription_id=$(SUBSCRIPTION_ID)"

destroy: ## Destroy Terraform-managed infrastructure
	@if [ -z "$(SUBSCRIPTION_ID)" ]; then \
		echo "Error: SUBSCRIPTION_ID is required. Use 'make destroy SUBSCRIPTION_ID=your-subscription-id'"; \
		exit 1; \
	fi
	az account set --subscription $(SUBSCRIPTION_ID) && \
	cd terraform && terraform destroy -var="subscription_id=$(SUBSCRIPTION_ID)"