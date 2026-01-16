resource "azurerm_resource_group" "connectivity" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

data "terraform_remote_state" "app_vnet" {
  backend = "local"
  config = {
    path = "C:/LocalApps/GithubWorkspaces/cx-statestore/cx-app-vnet/terraform.tfstate"
  }
}


module "connectivity_virtual_wan" {
  source  = "Azure/avm-ptn-alz-connectivity-virtual-wan/azurerm"
  version = "0.13.2"

  enable_telemetry = var.enable_module_telemetry
  tags             = var.tags

  virtual_hubs = {
    primary = {
      location          = var.location
      default_parent_id = azurerm_resource_group.connectivity.id
      # Toggle additional hub resources without editing the module call.
      enabled_resources = {
        # "Secure hub" = Virtual Hub with Azure Firewall (secured virtual hub).
        firewall                              = var.deploy_firewall
        firewall_policy                       = var.deploy_firewall_policy
        bastion                               = var.deploy_bastion
        virtual_network_gateway_express_route = var.deploy_expressroute_gateway
        virtual_network_gateway_vpn           = var.deploy_vpn_gateway
        private_dns_zones                     = var.deploy_private_dns
        private_dns_resolver                  = var.deploy_private_dns_resolver
        sidecar_virtual_network               = var.deploy_sidecar_virtual_network
      }
      hub = {
        name                                   = var.virtual_hub_name
        address_prefix                         = var.virtual_hub_address_prefix
        hub_routing_preference                 = var.virtual_hub_routing_preference
        virtual_router_auto_scale_min_capacity = 2
      }

      # NOTE: Azure Firewall (Standard) zonal deployment isn't supported in all regions.
      # Southeast Asia currently errors with:
      #   AzureFirewallUnsupportedAvailabilityZone
      # so we force a non-zonal deployment by explicitly passing an empty zones list.
      firewall = {
        zones = []
      }
    }
  }

  virtual_wan_settings = {
    enabled_resources = {
      ddos_protection_plan = false
    }
    virtual_wan = {
      name                           = var.virtual_wan_name
      location                       = var.location
      resource_group_name            = var.resource_group_name
      type                           = var.virtual_wan_sku
      allow_branch_to_branch_traffic = var.allow_branch_to_branch_traffic
      disable_vpn_encryption         = var.disable_vpn_encryption
    }
  }
}

// -----------------------------------------------------------------------------
// AKS forced-tunnel enablement
// -----------------------------------------------------------------------------

resource "azurerm_firewall_policy_rule_collection_group" "aks_egress" {
  name               = "rcg-aks-egress"
  firewall_policy_id = module.connectivity_virtual_wan.firewall_policy_resource_ids["primary"]
  priority           = 100

  network_rule_collection {
    name     = "net-aks-dns"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "allow-dns"
      protocols             = ["UDP", "TCP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["53"]
    }
  }

  application_rule_collection {
    name     = "app-aks-bootstrap"
    priority = 200
    action   = "Allow"

    rule {
      name             = "allow-http-https"
      source_addresses = ["*"]

      protocols {
        type = "Http"
        port = 80
      }

      protocols {
        type = "Https"
        port = 443
      }

      // Broad allow to unblock provisioning. Tighten this later.
      destination_fqdns = ["*"]
    }
  }
}
