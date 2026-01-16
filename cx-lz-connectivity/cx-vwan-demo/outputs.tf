output "virtual_wan_id" {
  description = "Resource ID of the deployed Virtual WAN."
  value       = module.connectivity_virtual_wan.resource_id
}

output "virtual_hub_resource_ids" {
  description = "Map of virtual hub resource IDs keyed by hub identifier."
  value       = module.connectivity_virtual_wan.virtual_hub_resource_ids
}

output "virtual_hub_resource_names" {
  description = "Map of virtual hub resource names keyed by hub identifier."
  value       = module.connectivity_virtual_wan.virtual_hub_resource_names
}
