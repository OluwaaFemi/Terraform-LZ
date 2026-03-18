locals {
  resource_group_resource_ids = merge(
    { for key, mod in module.resource_groups : key => mod.resource_id },
    { for key, rg in data.azurerm_resource_group.rg : key => rg.id }
  )

  firewall_policy_ids = merge(
    { for key, mod in module.firewall_policies : key => mod.resource_id },
    { for key, fp in data.azurerm_firewall_policy.existing : key => fp.id }
  )

  network_security_group_ids = merge(
    { for key, nsg in module.network_security_groups : key => nsg.resource_id },
    { for key, nsg in data.azurerm_network_security_group.existing : key => nsg.id }
  )

  role_assignments_azure_resource_manager_effective = {
    for assignment_key, assignment in var.role_assignments_azure_resource_manager : assignment_key => merge(
      { for k, v in assignment : k => v if k != "scope_resource_group_key" },
      (
        try(assignment.scope, null) != null ? {}
        : try(assignment.scope_resource_group_key, null) != null ? { scope = local.resource_group_resource_ids[assignment.scope_resource_group_key] }
        : {}
      )
    )
  }

  virtual_hubs_effective = {
    for hub_key, hub in var.virtual_hubs : hub_key => merge(
      { for k, v in hub : k => v if k != "default_parent_resource_group_key" },
      (
        try(hub.default_parent_id, null) != null ? {}
        : try(hub.default_parent_resource_group_key, null) != null ? { default_parent_id = local.resource_group_resource_ids[hub.default_parent_resource_group_key] }
        : {}
      ),
      (
        try(hub.firewall, null) == null ? {}
        : {
          firewall = merge(
            { for k, v in hub.firewall : k => v if k != "firewall_policy_key" },
            (
              try(hub.firewall.firewall_policy_id, null) != null ? {}
              : try(hub.firewall.firewall_policy_key, null) != null ? { firewall_policy_id = local.firewall_policy_ids[hub.firewall.firewall_policy_key] }
              : {}
            )
          )
        }
      ),
      (
        try(hub.sidecar_virtual_network, null) == null ? {}
        : {
          sidecar_virtual_network = merge(
            hub.sidecar_virtual_network,
            (
              try(hub.sidecar_virtual_network.subnets, null) == null ? {}
              : {
                subnets = {
                  for subnet_key, subnet in hub.sidecar_virtual_network.subnets : subnet_key => merge(
                    subnet,
                    (
                      try(subnet.network_security_group, null) == null ? {}
                      : {
                        network_security_group = merge(
                          { for k, v in subnet.network_security_group : k => v if k != "key" },
                          (
                            try(subnet.network_security_group.id, null) != null ? {}
                            : try(subnet.network_security_group.key, null) != null ? { id = local.network_security_group_ids[subnet.network_security_group.key] }
                            : {}
                          )
                        )
                      }
                    )
                  )
                }
              }
            )
          )
        }
      )
    )
  }
}
