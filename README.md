> [!IMPORTANT]
> This repository uses **Azure Verified Modules (AVM)** and is intended as a reference implementation.
> Any input values, defaults, and examples provided here are **samples only**.
> Review and adapt the configuration to meet your organization’s requirements (security, networking, naming, regions, compliance, etc.) before using it.

> [!NOTE]
> AVM modules may introduce changes over time (including breaking changes). For AVM bugs or feature requests, please raise issues with the relevant AVM module repository.

# msft-eslz-connectivity

Terraform configuration to deploy a Virtual WAN based connectivity foundation using AVM modules.

## What this deploys

Per environment (dev/prod) this repo can deploy:

- Resource groups (optional; managed via `resource_groups`)
- Firewall policies + rule collection groups (tfvars-driven)
- Virtual hubs (vHubs)
- Optional secured hubs (Azure Firewall `AZFW_Hub` attached to a vHub)
- Optional ExpressRoute gateways (in each vHub)
- Optional ExpressRoute circuits (one or many; provider-based or ExpressRoute Direct)

Virtual WAN (vWAN) is intended to be created **once** (typically in prod) and referenced from other environments.

## Repo layout

- `modules/`
	- `modules/vwan`: AVM Virtual WAN wrapper
	- `modules/vhub`: AVM Virtual Hub wrapper + optional Azure Firewall
	- `modules/fwpolicy`: Azure Firewall Policy + rule collection groups
	- `modules/expressroute_gateway`: AVM ExpressRoute Gateway (vWAN/vHub) wrapper
	- `modules/expressroute_circuit`: AVM ExpressRoute Circuit wrapper
- `environments/`
	- `environments/dev/backend.hcl` + `environments/dev/terraform.tfvars`
	- `environments/prod/backend.hcl` + `environments/prod/terraform.tfvars`

## Prerequisites

- Terraform `>= 1.9, < 2.0`
- Azure permissions for the identity you use (Azure CLI locally, or GitHub OIDC in CI)
- Existing remote state storage (Storage Account + Container) referenced by each `backend.hcl`

### Azure permissions (minimum guidance)

The executing identity typically needs, at minimum:

- On the hub subscription(s): permissions to create/read RGs, vHubs, firewalls, firewall policies, and optionally ExpressRoute resources.
- On the vWAN subscription (if different): permissions to create/read vWAN (prod) and/or read vWAN (dev).
- On the state subscription: permissions to read/write blob state (Storage Account).

If you see `403` errors like `Microsoft.Resources/subscriptions/providers/read`, assign at least `Reader` at subscription scope plus appropriate contributor rights for the resources you manage.

## Configuration model

This repo uses a single root module with environment-specific tfvars.

Key inputs:

- `resource_groups` / `existing_resource_groups`
- `virtual_wan` (managed) **or** `existing_virtual_wan` (lookup) — exactly one must be set
- `virtual_hubs` map (each hub can include optional `firewall` and optional `expressroute_gateway`)
- `firewall_policies` map
- `expressroute_circuits` map (optional)

### Multi-subscription support

If your hub resources and vWAN live in different subscriptions, set:

- `hub_subscription_id` / `hub_tenant_id`
- `virtual_wan_subscription_id` / `virtual_wan_tenant_id` (optional; defaults to hub values)

Tip: you can override tfvars without committing IDs by using environment variables, e.g. `TF_VAR_hub_subscription_id`.

## How to run locally

From the repo root:

- Prod:
	- `terraform init -backend-config=environments/prod/backend.hcl`
	- `terraform plan -var-file=environments/prod/terraform.tfvars`
	- `terraform apply -var-file=environments/prod/terraform.tfvars`

- Dev:
	- `terraform init -backend-config=environments/dev/backend.hcl`
	- `terraform plan -var-file=environments/dev/terraform.tfvars`
	- `terraform apply -var-file=environments/dev/terraform.tfvars`

### Recommended apply order

If dev references an existing vWAN (via `existing_virtual_wan`), run **prod first** so the vWAN exists, then run dev.

## How to run via GitHub Actions

Workflow: `.github/workflows/terraform.yml`

- `pull_request` to `main` runs **plan** for `dev` and `prod`.
- `push` to `main` runs **plan + apply**.
- `workflow_dispatch` supports `plan` or `apply`.

The workflow uses `azure/login@v2` OIDC and expects repo variables (or defaults):

- `ARM_CLIENT_ID`
- `ARM_TENANT_ID`
- `ARM_SUBSCRIPTION_ID` (used only for Azure login context; Terraform uses subscription IDs from tfvars)

Make sure the GitHub OIDC app registration has federated credentials for this repo/branch.

## ExpressRoute notes

### ExpressRoute gateway (Virtual WAN)

The vWAN ExpressRoute Gateway is created **inside the vHub** (no VNet required). Configure it per hub under:

- `virtual_hubs.<hub>.expressroute_gateway` (name + `scale_units` + optional tags)

### ExpressRoute circuits

ExpressRoute circuits are created via `expressroute_circuits` (map), allowing multiple circuits per environment.

Important operational note:

1. Create the circuit first (no peerings / no connections)
2. Share the **service key** with your provider and wait until the circuit shows **Provisioned**
3. Then add `peerings` and/or `er_gw_connections`

If you try to configure peerings before the circuit is provisioned, applies can fail.

## Outputs

Useful root outputs include:

- `virtual_wan_id`
- `virtual_hub_ids`
- `virtual_hub_firewall_ids`
- `expressroute_gateway_ids`
- `expressroute_circuit_ids`

## Legacy stack layout (kept for reference)

This repository was previously organized under a top-level folder named `msft-lz-connectivity/`.

As part of a repo restructure, the connectivity stacks were moved to the repository root:

- `msft-vwan-prod/`
- `msft-fwpolicy-dev/`
- `msft-vhub-dev/`
- `msft-fwpolicy-prod/`
- `msft-vhub-prod/`

Remote state keys were intentionally kept unchanged (still prefixed with `msft-lz-connectivity/`) to avoid any state migration.

This folder contains the Terraform stacks that make up the **Connectivity Landing Zone** used in this repo.

The design goal is:
- Deploy **one shared Virtual WAN** (vWAN)
- Deploy **two secured hubs** (vHubs) in separate resource groups (prod + dev)
- Manage **Azure Firewall Policy** independently from the hubs ("Option B"), so policy changes don’t cause hub re-deployments

All stacks are configured with a **local backend** and store state files outside the repo under:

- `C:/LocalApps/GithubWorkspaces/cx-statestore/<stack>/terraform.tfstate`

> Note: This repo follows a “one stack = one folder = one state file” approach.

## Disclaimer

> [!IMPORTANT]
> This repository uses **Azure Verified Modules (AVM)** and is intended as a reference implementation.
> Any input values, defaults, and examples provided here are **samples only**.
>
> You are responsible for reviewing and adapting the configuration to meet your organization’s requirements (security, networking, naming, regions, compliance, etc.) before using it in any environment.

> [!NOTE]
> AVM modules may introduce changes over time (including breaking changes). The maintainers of this repository are not responsible for upstream module changes.
> For AVM-related bugs or feature requests, please raise issues with the relevant AVM module repository.

## Stack layout

### `msft-vwan-prod/`
Creates the shared Virtual WAN.

- Uses the AVM submodule: `Azure/avm-ptn-alz-connectivity-virtual-wan/azurerm//modules/virtual-wan`
- Outputs:
	- `virtual_wan_id`

The hubs attach to this vWAN by looking it up directly with `data.azurerm_virtual_wan`.

### `msft-vhub-prod/`
Creates the **prod** secured virtual hub and Azure Firewall (Hub SKU).

- Uses the AVM submodule: `Azure/avm-ptn-alz-connectivity-virtual-wan/azurerm//modules/virtual-hub`
- Creates:
	- Resource group (prod hub RG)
	- Virtual Hub
	- Azure Firewall (`AZFW_Hub`)
- Looks up existing resources:
	- Virtual WAN (`data.azurerm_virtual_wan`)
	- Firewall policy (`data.azurerm_firewall_policy`)

### `msft-vhub-dev/`
Same as prod hub stack, but for **dev**.

### `msft-fwpolicy-prod/`
Owns the **Azure Firewall Policy** for the prod hub.

- Creates:
	- `azurerm_firewall_policy`
	- Rule collection groups (RCGs)
		- `baseline` (placeholder, priority 1000)
		- `aks-egress` (priority 200): baseline AKS outbound rules for UDR egress

This stack outputs:
- `firewall_policy_id`

The prod hub stack attaches this policy via `azurerm_firewall.firewall_policy_id`.

### `msft-fwpolicy-dev/`
Same as prod firewall policy stack, but for **dev**.

## How the stacks connect

- `msft-vwan-prod` is deployed first.
- `msft-vhub-prod` and `msft-vhub-dev` look up the existing vWAN directly (no dependency on terraform remote state).
- Each hub looks up its firewall policy directly.

## Recommended workflow

1. Deploy vWAN:
	 - `msft-vwan-prod/`
2. Deploy policies:
	 - `msft-fwpolicy-prod/`
	 - `msft-fwpolicy-dev/`
3. Deploy hubs:
	 - `msft-vhub-prod/`
	 - `msft-vhub-dev/`
4. Iterating on egress rules should normally only require changing/applying the `msft-fwpolicy-*` stacks.

## Notes / gotchas

- Defaults in the AKS egress rules currently use `"*"` for `source_addresses` to keep initial bring-up simple.
	- Before routing real AKS node egress through the firewall, tighten `aks_egress_source_addresses` to your AKS node subnet CIDR(s).
- On Windows with Git Bash, `terraform import` can sometimes mangle Azure resource IDs due to path conversion. If you need imports again, we can repeat the earlier workaround we used during the Option B migration.
