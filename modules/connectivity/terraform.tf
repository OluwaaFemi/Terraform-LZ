terraform {
  required_providers {
    azurerm = {
      source                = "hashicorp/azurerm"
      configuration_aliases = [azurerm.wan]
    }
    azapi = {
      source                = "Azure/azapi"
      configuration_aliases = [azapi.wan]
    }
  }
}
