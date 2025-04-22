# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- Initialize Terraform: `cd terraform && terraform init`
- Validate Terraform: `cd terraform && terraform validate`
- Plan Deployment: `cd terraform && terraform plan -var="subscription_id=<subscription_id>"`
- Apply Deployment: `cd terraform && terraform apply -var="subscription_id=<subscription_id>"`
- Destroy Resources: `cd terraform && terraform destroy -var="subscription_id=<subscription_id>"`

## Code Style Guidelines

### Terraform

- Use snake_case for resource names, variable names, and output names
- Use descriptive names for resources and variables
- Include description for all variables and outputs
- Group related resources together
- Use default values for optional variables
- Add meaningful output values
- Use consistent module structure

### JSON

- Use consistent indentation (2 spaces)
- Follow standard JSON parameter file structure
- Use descriptive parameter value names

### General

- Always validate Terraform files before deployment
- Document all major components in README.md
- Keep resource declarations modular and reusable
