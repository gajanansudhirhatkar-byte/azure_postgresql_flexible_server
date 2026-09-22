terraform {
  # Compatible with the user's installed Terraform 1.9.8.
  # Administrator passwords are supplied through sensitive variables/pipeline secrets.
  required_version = ">= 1.9.8, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.81.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "= 2.12.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
  environment     = "usgovernment"
}

# provider "azapi" {
#   subscription_id = var.subscription_id
#   tenant_id       = var.tenant_id
#   environment     = "usgovernment"
# }
