# Makefile for Azure Bicep and Terraform deployment

# Default variables
SUBSCRIPTION_ID ?= 0b962213-fc84-4c8d-bc1a-2dce59741c5a
PARAMETERS_FILE ?= bicep/parameters.json
LOCATION ?= northeurope
TEMPLATE_FILE ?= bicep/main.bicep
TF_DIR ?= terraform

.PHONY: help login set-subscription validate build lint deploy what-if clean tf-init tf-validate tf-plan tf-apply tf-destroy

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

validate: ## Validate Bicep template
	az bicep build --file $(TEMPLATE_FILE)

build: ## Build Bicep template
	az bicep build --file $(TEMPLATE_FILE) --stdout

lint: ## Lint Bicep template
	az bicep lint --file $(TEMPLATE_FILE)

what-if: ## Perform a what-if analysis of the deployment
	@if [ -z "$(SUBSCRIPTION_ID)" ]; then \
		echo "Error: SUBSCRIPTION_ID is required. Use 'make what-if SUBSCRIPTION_ID=your-subscription-id'"; \
		exit 1; \
	fi
	az account set --subscription $(SUBSCRIPTION_ID) && \
	az deployment sub what-if \
		--location $(LOCATION) \
		--template-file $(TEMPLATE_FILE) \
		--parameters $(PARAMETERS_FILE)

deploy: ## Deploy the Bicep template
	@if [ -z "$(SUBSCRIPTION_ID)" ]; then \
		echo "Error: SUBSCRIPTION_ID is required. Use 'make deploy SUBSCRIPTION_ID=your-subscription-id'"; \
		exit 1; \
	fi
	az account set --subscription $(SUBSCRIPTION_ID) && \
	az deployment sub create \
		--location $(LOCATION) \
		--template-file $(TEMPLATE_FILE) \
		--parameters $(PARAMETERS_FILE)

clean: ## Clean up compiled artifacts
	@rm -f bicep/*.json.bicep

# Terraform commands
tf-init: ## Initialize Terraform
	@if [ -d "$(TF_DIR)" ]; then \
		cd $(TF_DIR) && terraform init; \
	else \
		echo "Error: Terraform directory '$(TF_DIR)' not found"; \
		exit 1; \
	fi

tf-validate: ## Validate Terraform configuration
	@if [ -d "$(TF_DIR)" ]; then \
		cd $(TF_DIR) && terraform validate; \
	else \
		echo "Error: Terraform directory '$(TF_DIR)' not found"; \
		exit 1; \
	fi

tf-plan: ## Preview Terraform changes
	@if [ -z "$(SUBSCRIPTION_ID)" ]; then \
		echo "Error: SUBSCRIPTION_ID is required. Use 'make tf-plan SUBSCRIPTION_ID=your-subscription-id'"; \
		exit 1; \
	fi
	@if [ -d "$(TF_DIR)" ]; then \
		az account set --subscription $(SUBSCRIPTION_ID) && \
		cd $(TF_DIR) && terraform plan; \
	else \
		echo "Error: Terraform directory '$(TF_DIR)' not found"; \
		exit 1; \
	fi

tf-apply: ## Apply Terraform configuration
	@if [ -z "$(SUBSCRIPTION_ID)" ]; then \
		echo "Error: SUBSCRIPTION_ID is required. Use 'make tf-apply SUBSCRIPTION_ID=your-subscription-id'"; \
		exit 1; \
	fi
	@if [ -d "$(TF_DIR)" ]; then \
		az account set --subscription $(SUBSCRIPTION_ID) && \
		cd $(TF_DIR) && terraform apply; \
	else \
		echo "Error: Terraform directory '$(TF_DIR)' not found"; \
		exit 1; \
	fi

tf-destroy: ## Destroy Terraform-managed infrastructure
	@if [ -z "$(SUBSCRIPTION_ID)" ]; then \
		echo "Error: SUBSCRIPTION_ID is required. Use 'make tf-destroy SUBSCRIPTION_ID=your-subscription-id'"; \
		exit 1; \
	fi
	@if [ -d "$(TF_DIR)" ]; then \
		az account set --subscription $(SUBSCRIPTION_ID) && \
		cd $(TF_DIR) && terraform destroy; \
	else \
		echo "Error: Terraform directory '$(TF_DIR)' not found"; \
		exit 1; \
	fi