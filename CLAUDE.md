# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- Validate Bicep: `az bicep build --file main.bicep`
- Lint Bicep: `az bicep lint --file main.bicep`
- What-If Deployment: `az deployment group what-if --resource-group <group> --template-file main.bicep --parameters parameters.json`
- Deploy: `az deployment group create --resource-group <group> --template-file main.bicep --parameters parameters.json`

## Code Style Guidelines

### Bicep

- Use camelCase for parameter names and resource symbolic names
- Use descriptive parameter and resource names
- Include `@description` annotations for all parameters
- Group related parameters together
- Use default values for optional parameters
- Add meaningful output values

### JSON

- Use consistent indentation (2 spaces)
- Follow standard JSON parameter file structure
- Use descriptive parameter value names

### General

- Always validate Bicep files before deployment
- Document all major components in README.md
- Keep resource declarations modular and reusable
