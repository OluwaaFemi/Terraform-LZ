locals {
  virtual_wan_sku = try(var.virtual_wan.sku, "Standard")
  virtual_wan_tags = var.virtual_wan == null ? {} : merge(
    try(local.rg[var.virtual_wan.resource_group_key].tags, {}),
    try(var.virtual_wan.tags, {})
  )
}

locals {
  use_root_wan_module = var.virtual_wan != null
}

locals {
  virtual_hubs_effective = {
    for hub_key, hub in var.virtual_hubs : hub_key => {
      location            = hub.location
      resource_group_id   = local.rg[hub.resource_group_key].id
      resource_group_name = local.rg[hub.resource_group_key].name
      tags = merge(
        local.rg[hub.resource_group_key].tags,
        try(hub.tags, {})
      )

      name           = hub.name
      address_prefix = hub.address_prefix

      firewall             = try(hub.firewall, null)
      expressroute_gateway = try(hub.expressroute_gateway, null)
      site_to_site_vpn     = try(hub.site_to_site_vpn, null)
      private_dns_resolver = try(hub.private_dns_resolver, null)
    }
  }
}

module "resource_groups" {
  for_each = var.resource_groups

  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "0.2.2"

  name     = each.value.name
  location = each.value.location
  tags     = each.value.tags

  enable_telemetry = false
}

data "azurerm_resource_group" "rg" {
  for_each = var.existing_resource_groups

  name = each.value.name
}

locals {
  rg = merge(
    { for rg_key, rg_mod in module.resource_groups : rg_key => { id = rg_mod.resource_id, name = rg_mod.name, location = rg_mod.location, tags = coalesce(try(rg_mod.resource.tags, null), try(var.resource_groups[rg_key].tags, {})) } },
    { for rg_key, rg_data in data.azurerm_resource_group.rg : rg_key => { id = rg_data.id, name = rg_data.name, location = rg_data.location, tags = rg_data.tags } }
  )
}

data "azurerm_virtual_wan" "existing" {
  count = local.use_root_wan_module ? 0 : 1

  provider = azurerm.wan

  name                = var.existing_virtual_wan.name
  resource_group_name = var.existing_virtual_wan.resource_group_name
}

locals {
  virtual_wan_id = local.use_root_wan_module ? module.alz_connectivity[0].resource_id : data.azurerm_virtual_wan.existing[0].id
}

module "alz_connectivity" {
  count   = local.use_root_wan_module ? 1 : 0
  source  = "Azure/avm-ptn-alz-connectivity-virtual-wan/azurerm"
  version = "0.13.5"

  providers = {
    azurerm = azurerm.wan
    azapi   = azapi.wan
  }

  enable_telemetry = try(var.virtual_wan.enable_module_telemetry, true)
  tags             = local.virtual_wan_tags

  virtual_wan_settings = {
    enabled_resources = {
      ddos_protection_plan = false
    }

    virtual_wan = {
      name                = var.virtual_wan.name
      location            = var.virtual_wan.location
      resource_group_name = local.rg[var.virtual_wan.resource_group_key].name
      type                = local.virtual_wan_sku

      allow_branch_to_branch_traffic = try(var.virtual_wan.allow_branch_to_branch_traffic, true)
      disable_vpn_encryption         = try(var.virtual_wan.disable_vpn_encryption, false)

      tags = local.virtual_wan_tags
    }
  }

  virtual_hubs = {
    for hub_key, hub in local.virtual_hubs_effective : hub_key => {
      location = hub.location

      enabled_resources = {
        firewall                              = hub.firewall != null
        firewall_policy                       = false
        bastion                               = false
        virtual_network_gateway_express_route = false
        virtual_network_gateway_vpn           = false
        private_dns_zones                     = false
        private_dns_resolver                  = false
        sidecar_virtual_network               = false
      }

      hub = {
        name           = hub.name
        address_prefix = hub.address_prefix
        parent_id      = hub.resource_group_id
        tags           = hub.tags
      }

      firewall = hub.firewall != null ? {
        name     = try(hub.firewall.name, null)
        sku_name = "AZFW_Hub"
        sku_tier = coalesce(try(hub.firewall.sku_tier, null), "Standard")
        firewall_policy_id = coalesce(
          try(hub.firewall.firewall_policy_id, null),
          try(local.firewall_policy_ids[hub.firewall.firewall_policy_key], null)
        )
        zones = []
        tags  = coalesce(try(hub.firewall.tags, null), hub.tags)
        } : {
        name               = null
        sku_name           = "AZFW_Hub"
        sku_tier           = "Standard"
        firewall_policy_id = null
        zones              = []
        tags               = null
      }
    }
  }
}

module "virtual_hubs" {
  for_each = local.use_root_wan_module ? {} : local.virtual_hubs_effective

  source = "./modules/vhub"

  name                = each.value.name
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  address_prefix      = each.value.address_prefix

  virtual_wan_id = local.virtual_wan_id

  tags = each.value.tags

  create_firewall   = each.value.firewall != null
  firewall_name     = try(each.value.firewall.name, null)
  firewall_sku_tier = coalesce(try(each.value.firewall.sku_tier, null), "Standard")

  firewall_policy_id = each.value.firewall != null ? coalesce(
    try(each.value.firewall.firewall_policy_id, null),
    try(local.firewall_policy_ids[each.value.firewall.firewall_policy_key], null)
  ) : null

  firewall_extra_tags = each.value.firewall != null ? try(each.value.firewall.tags, {}) : {}
}

locals {
  virtual_hub_ids          = local.use_root_wan_module ? module.alz_connectivity[0].virtual_hub_resource_ids : { for hub_key, hub_mod in module.virtual_hubs : hub_key => hub_mod.hub_id }
  virtual_hub_firewall_ids = local.use_root_wan_module ? module.alz_connectivity[0].firewall_resource_ids : { for hub_key, hub_mod in module.virtual_hubs : hub_key => hub_mod.firewall_id }
}

module "private_dns_resolvers" {
  for_each = {
    for hub_key, hub in var.virtual_hubs : hub_key => hub
    if try(hub.private_dns_resolver, null) != null
  }

  source = "./modules/private_dns_resolver"

  name     = coalesce(try(each.value.private_dns_resolver.name, null), "${each.value.name}-pdr")
  location = each.value.location

  resource_group_name = local.rg[coalesce(
    try(each.value.private_dns_resolver.resource_group_key, null),
    each.value.resource_group_key
  )].name

  resource_group_id = local.rg[coalesce(
    try(each.value.private_dns_resolver.resource_group_key, null),
    each.value.resource_group_key
  )].id

  virtual_hub_id = local.virtual_hub_ids[each.key]

  tags = merge(
    local.rg[coalesce(
      try(each.value.private_dns_resolver.resource_group_key, null),
      each.value.resource_group_key
    )].tags,
    try(each.value.tags, {}),
    try(each.value.private_dns_resolver.tags, {})
  )

  sidecar_virtual_network = each.value.private_dns_resolver.sidecar_virtual_network
  inbound_subnet          = each.value.private_dns_resolver.inbound_subnet
  outbound_subnet         = each.value.private_dns_resolver.outbound_subnet

  inbound_endpoints   = try(each.value.private_dns_resolver.inbound_endpoints, {})
  outbound_endpoints  = try(each.value.private_dns_resolver.outbound_endpoints, {})
  forwarding_rulesets = try(each.value.private_dns_resolver.forwarding_rulesets, {})
}

module "expressroute_gateways" {
  for_each = {
    for hub_key, hub in var.virtual_hubs : hub_key => hub
    if try(hub.expressroute_gateway, null) != null
  }

  source = "./modules/expressroute_gateway"

  name = coalesce(
    try(each.value.expressroute_gateway.name, null),
    "${each.value.name}-ergw"
  )

  location            = each.value.location
  resource_group_name = local.rg[each.value.resource_group_key].name
  virtual_hub_id      = local.virtual_hub_ids[each.key]

  tags = merge(
    local.rg[each.value.resource_group_key].tags,
    try(each.value.tags, {}),
    try(each.value.expressroute_gateway.tags, {})
  )

  allow_non_virtual_wan_traffic = try(each.value.expressroute_gateway.allow_non_virtual_wan_traffic, false)
  scale_units                   = try(each.value.expressroute_gateway.scale_units, 1)
}

module "site_to_site_vpns" {
  for_each = {
    for hub_key, hub in var.virtual_hubs : hub_key => hub
    if try(hub.site_to_site_vpn, null) != null
  }

  source = "./modules/site_to_site_vpn"

  location            = each.value.location
  resource_group_name = local.rg[each.value.resource_group_key].name
  virtual_hub_id      = local.virtual_hub_ids[each.key]
  virtual_wan_id      = local.virtual_wan_id

  tags = merge(
    local.rg[each.value.resource_group_key].tags,
    try(each.value.tags, {})
  )

  vpn_gateways         = try(each.value.site_to_site_vpn.vpn_gateways, {})
  vpn_sites            = try(each.value.site_to_site_vpn.vpn_sites, {})
  vpn_site_connections = try(each.value.site_to_site_vpn.vpn_site_connections, {})
}

module "firewall_policies" {
  for_each = var.firewall_policies

  source = "./modules/fwpolicy"

  name                = each.value.name
  location            = each.value.location
  resource_group_name = local.rg[each.value.resource_group_key].name

  tags = merge(
    local.rg[each.value.resource_group_key].tags,
    try(each.value.tags, {})
  )

  # Optional: built-in rule sets (opt-in) + fully custom rule collection groups for this policy.
  builtins               = try(each.value.builtins, {})
  rule_collection_groups = try(each.value.rule_collection_groups, {})
}

module "expressroute_circuits" {
  for_each = var.expressroute_circuits

  source = "./modules/expressroute_circuit"

  name                = each.value.name
  location            = coalesce(try(each.value.location, null), local.rg[each.value.resource_group_key].location)
  resource_group_name = local.rg[each.value.resource_group_key].name

  sku = each.value.sku

  service_provider_name = try(each.value.service_provider_name, null)
  peering_location      = try(each.value.peering_location, null)
  bandwidth_in_mbps     = try(each.value.bandwidth_in_mbps, null)

  express_route_port_resource_id = try(each.value.express_route_port_resource_id, null)
  bandwidth_in_gbps              = try(each.value.bandwidth_in_gbps, null)

  allow_classic_operations = try(each.value.allow_classic_operations, false)
  authorization_key        = try(each.value.authorization_key, null)

  tags = merge(
    local.rg[each.value.resource_group_key].tags,
    try(each.value.tags, {})
  )

  exr_circuit_tags = try(each.value.exr_circuit_tags, null)

  peerings                             = try(each.value.peerings, {})
  express_route_circuit_authorizations = try(each.value.express_route_circuit_authorizations, {})
  er_gw_connections                    = try(each.value.er_gw_connections, {})
  vnet_gw_connections                  = try(each.value.vnet_gw_connections, {})
  circuit_connections                  = try(each.value.circuit_connections, {})
  diagnostic_settings                  = try(each.value.diagnostic_settings, {})
  role_assignments                     = try(each.value.role_assignments, {})
  lock                                 = try(each.value.lock, null)
  enable_telemetry                     = try(each.value.enable_telemetry, true)
}

data "azurerm_firewall_policy" "existing" {
  for_each = var.existing_firewall_policies

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
}

locals {
  firewall_policy_ids = merge(
    { for policy_key, policy_mod in module.firewall_policies : policy_key => policy_mod.id },
    { for policy_key, policy_data in data.azurerm_firewall_policy.existing : policy_key => policy_data.id }
  )
}

