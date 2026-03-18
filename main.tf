module "connectivity" {
  source = "./modules/connectivity"

  providers = {
    azurerm     = azurerm
    azurerm.wan = azurerm.wan
    azapi       = azapi
    azapi.wan   = azapi.wan
  }

  resource_groups          = var.resource_groups
  existing_resource_groups = var.existing_resource_groups

  enable_telemetry = var.enable_telemetry
  tags             = var.tags

  default_naming_convention          = var.default_naming_convention
  default_naming_convention_sequence = var.default_naming_convention_sequence
  retry                              = var.retry
  timeouts                           = var.timeouts

  private_link_private_dns_zone_virtual_network_link_moved_block_template_module_prefix = var.private_link_private_dns_zone_virtual_network_link_moved_block_template_module_prefix

  virtual_wan_settings = var.virtual_wan_settings
  virtual_hubs         = var.virtual_hubs

  firewall_policies          = var.firewall_policies
  existing_firewall_policies = var.existing_firewall_policies

  network_security_groups          = var.network_security_groups
  existing_network_security_groups = var.existing_network_security_groups

  expressroute_circuits = var.expressroute_circuits

  firewall_log_analytics_workspaces             = var.firewall_log_analytics_workspaces
  expressroute_gateway_log_analytics_workspaces = var.expressroute_gateway_log_analytics_workspaces

  role_assignments_azure_resource_manager = var.role_assignments_azure_resource_manager

  firewall_diagnostic_log_analytics_destination_type = var.firewall_diagnostic_log_analytics_destination_type
  firewall_diagnostic_enabled_log_category_group     = var.firewall_diagnostic_enabled_log_category_group
  firewall_diagnostic_enabled_metric_category        = var.firewall_diagnostic_enabled_metric_category
  firewall_diagnostic_enabled_metric_enabled         = var.firewall_diagnostic_enabled_metric_enabled

  expressroute_gateway_diagnostic_enabled_metric_category = var.expressroute_gateway_diagnostic_enabled_metric_category
  expressroute_gateway_diagnostic_enabled_metric_enabled  = var.expressroute_gateway_diagnostic_enabled_metric_enabled
}

