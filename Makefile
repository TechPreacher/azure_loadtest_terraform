# Makefile for Azure Bicep deployment

# Default variables
SUBSCRIPTION_ID ?= 
PARAMETERS_FILE ?= parameters.json
LOCATION ?= northeurope
TEMPLATE_FILE ?= main.bicep

.PHONY: help login set-subscription validate build lint deploy what-if clean

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
	@rm -f *.json.bicep