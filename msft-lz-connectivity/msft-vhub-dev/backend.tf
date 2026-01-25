terraform {
  backend "azurerm" {
    resource_group_name  = "msft-tfstate-dev-rg"
    storage_account_name = "msfttfstatedev001"
    container_name       = "tfstate"
    key                  = "msft-lz-connectivity/msft-vhub-dev/terraform.tfstate"
  }
}
