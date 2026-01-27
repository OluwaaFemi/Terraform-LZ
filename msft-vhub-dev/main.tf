resource "azurerm_resource_group" "hub" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

data "azurerm_virtual_wan" "vwan" {
  name                = var.virtual_wan_name
  resource_group_name = var.virtual_wan_resource_group_name
}

data "azurerm_firewall_policy" "fwpolicy" {
  name                = var.firewall_policy_name
  resource_group_name = var.firewall_policy_resource_group_name
}

module "connectivity_virtual_hub" {
  source  = "Azure/avm-ptn-alz-connectivity-virtual-wan/azurerm//modules/virtual-hub"
  version = "0.13.5"

  virtual_hubs = {
    hub = {
      name                = var.virtual_hub_name
      location            = var.location
      resource_group_name = azurerm_resource_group.hub.name
      address_prefix      = var.hub_address_prefix
      virtual_wan_id      = data.azurerm_virtual_wan.vwan.id
      tags                = var.tags
    }
  }
}

resource "azurerm_firewall" "hub" {
  name                = var.firewall_name
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name

  sku_name = "AZFW_Hub"
  sku_tier = "Standard"

  virtual_hub {
    virtual_hub_id = module.connectivity_virtual_hub.resource["hub"].id
  }

  firewall_policy_id = data.azurerm_firewall_policy.fwpolicy.id

  tags = var.tags
}
