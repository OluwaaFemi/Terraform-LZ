# Dev firewall policy overrides
# NOTE: This allows inbound SSH (TCP/22) from a single admin public IP.
# Tighten/rotate as needed.

admin_ssh_source_cidrs = [
  "58.96.249.160/32"
]
