resource "azurerm_resource_group" "connectivity" {
  name     = "prod_hub_rg"
  location = "southeastasia"
  #   tags     = var.tags
}


module "avm-ptn-alz-connectivity-virtual-wan_virtual-hub" {
  source  = "Azure/avm-ptn-alz-connectivity-virtual-wan/azurerm//modules/virtual-hub"
  version = "0.13.4"
  virtual_hubs = {
    prod_hub = {
      name                = "cx-sea-prod-secure-hub"
      address_prefix      = "10.2.0.0/23"
      location            = azurerm_resource_group.connectivity.location
      resource_group_name = azurerm_resource_group.connectivity.name
      virtual_wan_id      = "/subscriptions/2f69b2b1-5fe0-487d-8c82-52f5edeb454e/resourceGroups/cx-demo-connectivity-rg/providers/Microsoft.Network/virtualWans/cx-sea-vwan"
      tags = {
        environment = "production"
        project     = "sharedservice"
      }
    }
  }
}
