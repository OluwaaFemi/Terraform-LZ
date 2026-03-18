#!/usr/bin/env bash
set -euo pipefail

# Creates an Entra app registration + service principal and configures GitHub Actions OIDC
# federated credentials for this repo.
#
# Prereqs:
# - Azure CLI installed and logged in (or provide AZ_TENANT_ID so the script can login)
# - Permissions to create app registrations + federated credentials
# - Permissions to create RBAC role assignments at the scopes you choose
#
# Usage (example):
#   export AZ_TENANT_ID="..."
#   export AZ_SUBSCRIPTION_ID="..."           # login context
#   export GH_ORG="cx-demo-org"
#   export GH_REPO="demo-eslz-connectivity-shared"
#   export GH_BRANCH="main"
#   export APP_NAME="${GH_REPO}-gha-oidc"
#
#   # Optional RBAC scopes (recommended):
#   export HUB_SCOPE_ID="/subscriptions/.../resourceGroups/rg-connectivity"
#   export STATE_SA_SCOPE_ID="/subscriptions/.../resourceGroups/rg-tfstate/providers/Microsoft.Storage/storageAccounts/sttfstate123"
#
#   ./documents/scripts/setup-github-oidc.sh

require() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

require az

AZ_TENANT_ID="${AZ_TENANT_ID:-}"
AZ_SUBSCRIPTION_ID="${AZ_SUBSCRIPTION_ID:-}"

GH_ORG="${GH_ORG:-}"
GH_REPO="${GH_REPO:-}"
GH_BRANCH="${GH_BRANCH:-main}"

APP_NAME="${APP_NAME:-${GH_REPO}-gha-oidc}"
OIDC_AUDIENCE="${OIDC_AUDIENCE:-api://AzureADTokenExchange}"

HUB_SCOPE_ID="${HUB_SCOPE_ID:-}"
HUB_ROLE="${HUB_ROLE:-Contributor}"

STATE_SA_SCOPE_ID="${STATE_SA_SCOPE_ID:-}"
STATE_SA_ROLE="${STATE_SA_ROLE:-Storage Blob Data Contributor}"

if [[ -z "$GH_ORG" || -z "$GH_REPO" ]]; then
  echo "Set GH_ORG and GH_REPO." >&2
  exit 1
fi

# Ensure we have an Azure login context.
if ! az account show >/dev/null 2>&1; then
  if [[ -z "$AZ_TENANT_ID" ]]; then
    echo "Not logged into Azure. Either run 'az login' or set AZ_TENANT_ID for the script to login." >&2
    exit 1
  fi
  echo "Logging into Azure tenant ${AZ_TENANT_ID}..."
  az login --tenant "$AZ_TENANT_ID" >/dev/null
fi

if [[ -n "$AZ_SUBSCRIPTION_ID" ]]; then
  az account set --subscription "$AZ_SUBSCRIPTION_ID"
fi

echo "Creating app registration: ${APP_NAME}"
APP_ID="$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)"
APP_OBJECT_ID="$(az ad app show --id "$APP_ID" --query id -o tsv)"

# Create SP
az ad sp create --id "$APP_ID" >/dev/null
SP_OBJECT_ID="$(az ad sp show --id "$APP_ID" --query id -o tsv)"

echo "APP_ID=${APP_ID}"
echo "APP_OBJECT_ID=${APP_OBJECT_ID}"
echo "SP_OBJECT_ID=${SP_OBJECT_ID}"

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

push_json="$tmpdir/federated-cred-push.json"
pr_json="$tmpdir/federated-cred-pr.json"

cat >"$push_json" <<JSON
{
  "name": "github-push-${GH_BRANCH}",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GH_ORG}/${GH_REPO}:ref:refs/heads/${GH_BRANCH}",
  "description": "GitHub Actions OIDC - push/manual runs on branch",
  "audiences": ["${OIDC_AUDIENCE}"]
}
JSON

cat >"$pr_json" <<JSON
{
  "name": "github-pull-request",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GH_ORG}/${GH_REPO}:pull_request",
  "description": "GitHub Actions OIDC - pull_request runs",
  "audiences": ["${OIDC_AUDIENCE}"]
}
JSON

echo "Creating federated credential: push/${GH_BRANCH}"
az ad app federated-credential create --id "$APP_OBJECT_ID" --parameters "@$push_json" >/dev/null

echo "Creating federated credential: pull_request"
az ad app federated-credential create --id "$APP_OBJECT_ID" --parameters "@$pr_json" >/dev/null

ensure_role_assignment() {
  local scope="$1"
  local role="$2"

  if [[ -z "$scope" ]]; then
    return 0
  fi

  existing_id="$(az role assignment list \
    --assignee-object-id "$SP_OBJECT_ID" \
    --scope "$scope" \
    --role "$role" \
    --query "[0].id" -o tsv 2>/dev/null || true)"

  if [[ -n "$existing_id" ]]; then
    echo "RBAC already present: role='${role}' scope='${scope}'"
    return 0
  fi

  echo "Creating RBAC: role='${role}' scope='${scope}'"
  az role assignment create \
    --assignee-object-id "$SP_OBJECT_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "$role" \
    --scope "$scope" \
    >/dev/null
}

# Optional: RBAC (provide scopes as env vars)
ensure_role_assignment "$HUB_SCOPE_ID" "$HUB_ROLE"
ensure_role_assignment "$STATE_SA_SCOPE_ID" "$STATE_SA_ROLE"

cat <<OUT

Next steps (GitHub repo variables):
- ARM_CLIENT_ID=${APP_ID}
- ARM_TENANT_ID=${AZ_TENANT_ID:-<your-tenant-id>}
- ARM_SUBSCRIPTION_ID=${AZ_SUBSCRIPTION_ID:-<login-context-subscription-id>}

Notes:
- If you change the workflow to run from a different branch, create another federated credential with subject:
  repo:${GH_ORG}/${GH_REPO}:ref:refs/heads/<branch>
- RBAC role assignments are optional in this script; set HUB_SCOPE_ID / STATE_SA_SCOPE_ID to enable them.

OUT
