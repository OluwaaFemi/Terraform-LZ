output "id" {
  description = "ExpressRoute Gateway resource ID."
  value       = module.this.resource_id["gateway"]
}

output "name" {
  description = "ExpressRoute Gateway resource name."
  value       = module.this.resource["gateway"]
}

output "resource_object" {
  description = "ExpressRoute Gateway resource object."
  value       = module.this.resource_object["gateway"]
}
