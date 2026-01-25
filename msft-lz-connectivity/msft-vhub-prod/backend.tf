terraform {
  backend "azurerm" {
    resource_group_name  = "msft-tfstate-prod-rg"
    storage_account_name = "msfttfstateprod001"
    container_name       = "tfstate"
    key                  = "msft-lz-connectivity/msft-vhub-prod/terraform.tfstate"
  }
}
