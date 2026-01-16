variable "location" {
  description = "Azure region for the Virtual WAN and hub resources."
  type        = string
  default     = "southeastasia"
}

variable "resource_group_name" {
  description = "Name of the existing resource group that hosts the Virtual WAN resources."
  type        = string
  default     = "cx-demo-con-rg"
}

variable "virtual_wan_name" {
  description = "Name for the Virtual WAN resource."
  type        = string
  default     = "cx-demo-sea-vwan"
}

variable "virtual_wan_sku" {
  description = "Virtual WAN SKU. Allowed values are Standard or Basic."
  type        = string
  default     = "Standard"
}

variable "allow_branch_to_branch_traffic" {
  description = "Toggle branch-to-branch traffic within the Virtual WAN."
  type        = bool
  default     = true
}

variable "disable_vpn_encryption" {
  description = "Disable VPN encryption on the Virtual WAN (not recommended)."
  type        = bool
  default     = false
}

variable "virtual_hub_name" {
  description = "Name for the primary Virtual Hub."
  type        = string
  default     = "cx-sea-prd-secure-hub"
}

variable "virtual_hub_address_prefix" {
  description = "CIDR prefix assigned to the Virtual Hub (recommend a /23)."
  type        = string
  default     = "10.220.0.0/23"
}

variable "virtual_hub_routing_preference" {
  description = "Routing preference for the Virtual Hub (ExpressRoute, VpnGateway, or ASPath)."
  type        = string
  default     = "ExpressRoute"
}

variable "deploy_firewall" {
  description = "Deploy Azure Firewall in the Virtual Hub."
  type        = bool
  default     = true
}

variable "deploy_firewall_policy" {
  description = "Deploy Azure Firewall Policy alongside the firewall."
  type        = bool
  default     = true
}

variable "deploy_bastion" {
  description = "Deploy Azure Bastion in the sidecar virtual network."
  type        = bool
  default     = false
}

variable "deploy_expressroute_gateway" {
  description = "Deploy an ExpressRoute gateway in the Virtual Hub."
  type        = bool
  default     = false
}

variable "deploy_vpn_gateway" {
  description = "Deploy a VPN gateway in the Virtual Hub."
  type        = bool
  default     = false
}

variable "deploy_private_dns" {
  description = "Create the recommended private DNS zones for hub dependencies."
  type        = bool
  default     = false
}

variable "deploy_private_dns_resolver" {
  description = "Deploy the Azure DNS private resolver in the hub sidecar vnet."
  type        = bool
  default     = false
}

variable "deploy_sidecar_virtual_network" {
  description = "Provision the hub sidecar virtual network used by ancillary services."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Optional tags applied to all resources managed by this module."
  type        = map(string)
  default = {
    environment = "demo"
    workload    = "cx-vwan"
  }
}

variable "enable_module_telemetry" {
  description = "Enable AVM module telemetry (recommended)."
  type        = bool
  default     = true
}

# variable "aks_spoke_vnet_id" {
#   description = "Resource ID of the AKS spoke Virtual Network to connect to the secure hub. Can be cross-subscription."
#   type        = string
#   default     = null
#   nullable    = true
# }
