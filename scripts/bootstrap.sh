#!/usr/bin/env bash
# =============================================================================
# Azure Tenant Bootstrap — Pre-Terraform Setup Script
#
# PURPOSE:
#   Creates the foundational Azure resources that Terraform needs to run but
#   cannot self-bootstrap (state backend, service principal, OIDC federation,
#   root management group RBAC).
#
# PREREQUISITES:
#   - Azure CLI installed and logged in (az login)
#   - Account must have: Global Administrator + Owner on the management subscription
#   - jq installed (brew install jq)
#
# USAGE:
#   ./scripts/bootstrap.sh                  # real run
#   DRY_RUN=true ./scripts/bootstrap.sh     # echo mode — no changes
#
# IDEMPOTENCY:
#   All operations are guarded by existence checks. Safe to re-run.
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — edit these for your organisation
# ---------------------------------------------------------------------------
GITHUB_ORG="${GITHUB_ORG:-your-org}"
GITHUB_REPO="${GITHUB_REPO:-Bootstrap-Azure-Terraform}"
PREFIX="${PREFIX:-contoso}"                    # Short org prefix, lowercase
LOCATION="${LOCATION:-eastus}"
DRY_RUN="${DRY_RUN:-false}"

# Derived names
STATE_RG="rg-terraform-state-mgmt-${LOCATION}"
STATE_SA_SUFFIX=$(LC_ALL=C tr -dc 'a-z0-9' </dev/urandom 2>/dev/null | head -c 8 || echo "bootstrap")
STATE_SA_NAME="${PREFIX}tfstate${STATE_SA_SUFFIX}"
APP_NAME="sp-terraform-bootstrap-${PREFIX}"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[$(date -u +%H:%M:%S)] $*"; }
info() { echo -e "\033[36m[INFO]\033[0m  $*"; }
ok()   { echo -e "\033[32m[OK]\033[0m    $*"; }
warn() { echo -e "\033[33m[WARN]\033[0m  $*"; }
err()  { echo -e "\033[31m[ERROR]\033[0m $*" >&2; exit 1; }

run() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    echo "[DRY-RUN] $*"
  else
    eval "$@"
  fi
}

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
info "Checking prerequisites..."

command -v az  >/dev/null 2>&1 || err "Azure CLI (az) not found. Install from https://aka.ms/installazurecli"
command -v jq  >/dev/null 2>&1 || err "jq not found. Install with: brew install jq"

# Verify login
SIGNED_IN=$(az account show --query "user.name" -o tsv 2>/dev/null || true)
[[ -z "${SIGNED_IN}" ]] && err "Not logged in to Azure CLI. Run: az login"
info "Signed in as: ${SIGNED_IN}"

# Collect tenant/subscription context
TENANT_ID=$(az account show --query "tenantId" -o tsv)
SUBSCRIPTION_ID=$(az account show --query "id" -o tsv)
SUBSCRIPTION_NAME=$(az account show --query "name" -o tsv)

info "Tenant ID:          ${TENANT_ID}"
info "Subscription ID:    ${SUBSCRIPTION_ID}"
info "Subscription Name:  ${SUBSCRIPTION_NAME}"
info "Location:           ${LOCATION}"
info "State SA Name:      ${STATE_SA_NAME}"
echo ""
read -r -p "Proceed with bootstrap? [y/N] " confirm
[[ "${confirm}" =~ ^[Yy]$ ]] || { warn "Aborted."; exit 0; }

# ---------------------------------------------------------------------------
# Step 1: Resource Group for Terraform State
# ---------------------------------------------------------------------------
info "Step 1/6: Creating resource group for Terraform state..."

existing_rg=$(az group show --name "${STATE_RG}" --query "name" -o tsv 2>/dev/null || true)
if [[ -n "${existing_rg}" ]]; then
  ok "Resource group '${STATE_RG}' already exists — skipping."
else
  run az group create \
    --name "${STATE_RG}" \
    --location "${LOCATION}" \
    --tags "managed-by=bootstrap-script" "environment=platform" \
    --output none
  ok "Resource group '${STATE_RG}' created."
fi

# ---------------------------------------------------------------------------
# Step 2: Storage Account for Terraform State
# ---------------------------------------------------------------------------
info "Step 2/6: Creating storage account for Terraform state..."

# Check if a state SA already exists in the RG (there should be at most one)
existing_sa=$(az storage account list \
  --resource-group "${STATE_RG}" \
  --query "[0].name" -o tsv 2>/dev/null || true)

if [[ -n "${existing_sa}" ]]; then
  STATE_SA_NAME="${existing_sa}"
  ok "Storage account '${STATE_SA_NAME}' already exists — skipping creation."
else
  run az storage account create \
    --name "${STATE_SA_NAME}" \
    --resource-group "${STATE_RG}" \
    --location "${LOCATION}" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --access-tier Hot \
    --https-only true \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --allow-shared-key-access false \
    --tags "managed-by=bootstrap-script" "environment=platform" \
    --output none
  ok "Storage account '${STATE_SA_NAME}' created."
fi

# ---------------------------------------------------------------------------
# Step 3: Blob Containers for State
# ---------------------------------------------------------------------------
info "Step 3/6: Creating state blob containers..."

for container in bootstrap prod nonprod; do
  existing_container=$(az storage container show \
    --name "${container}" \
    --account-name "${STATE_SA_NAME}" \
    --auth-mode login \
    --query "name" -o tsv 2>/dev/null || true)

  if [[ -n "${existing_container}" ]]; then
    ok "Container '${container}' already exists — skipping."
  else
    run az storage container create \
      --name "${container}" \
      --account-name "${STATE_SA_NAME}" \
      --auth-mode login \
      --output none
    ok "Container '${container}' created."
  fi
done

# Enable versioning and soft delete for state protection
run az storage account blob-service-properties update \
  --account-name "${STATE_SA_NAME}" \
  --resource-group "${STATE_RG}" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30 \
  --output none
ok "Blob versioning and soft delete enabled."

# ---------------------------------------------------------------------------
# Step 4: App Registration + Service Principal
# ---------------------------------------------------------------------------
info "Step 4/6: Creating App Registration and Service Principal for Terraform..."

existing_app_id=$(az ad app list \
  --display-name "${APP_NAME}" \
  --query "[0].appId" -o tsv 2>/dev/null || true)

if [[ -n "${existing_app_id}" ]]; then
  CLIENT_ID="${existing_app_id}"
  ok "App Registration '${APP_NAME}' already exists (client ID: ${CLIENT_ID}) — skipping."
else
  CLIENT_ID=$(az ad app create \
    --display-name "${APP_NAME}" \
    --query "appId" -o tsv)
  ok "App Registration created (client ID: ${CLIENT_ID})."

  # Create service principal
  run az ad sp create --id "${CLIENT_ID}" --output none
  ok "Service principal created."
fi

# ---------------------------------------------------------------------------
# Step 5: OIDC Federated Credentials
# ---------------------------------------------------------------------------
info "Step 5/6: Creating OIDC federated identity credentials..."

# Credential for terraform plan (pull requests)
PLAN_CRED_NAME="github-actions-plan"
existing_plan_cred=$(az ad app federated-credential list \
  --id "${CLIENT_ID}" \
  --query "[?name=='${PLAN_CRED_NAME}'].name" -o tsv 2>/dev/null || true)

if [[ -n "${existing_plan_cred}" ]]; then
  ok "Plan federated credential already exists — skipping."
else
  run az ad app federated-credential create \
    --id "${CLIENT_ID}" \
    --parameters "{
      \"name\": \"${PLAN_CRED_NAME}\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:pull_request\",
      \"description\": \"GitHub Actions plan workflow (pull requests)\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" \
    --output none
  ok "Plan federated credential created (entity: pull_request)."
fi

# Credential for terraform apply (main branch via production environment)
APPLY_CRED_NAME="github-actions-apply-production"
existing_apply_cred=$(az ad app federated-credential list \
  --id "${CLIENT_ID}" \
  --query "[?name=='${APPLY_CRED_NAME}'].name" -o tsv 2>/dev/null || true)

if [[ -n "${existing_apply_cred}" ]]; then
  ok "Apply federated credential already exists — skipping."
else
  run az ad app federated-credential create \
    --id "${CLIENT_ID}" \
    --parameters "{
      \"name\": \"${APPLY_CRED_NAME}\",
      \"issuer\": \"https://token.actions.githubusercontent.com\",
      \"subject\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:production\",
      \"description\": \"GitHub Actions apply workflow (production environment)\",
      \"audiences\": [\"api://AzureADTokenExchange\"]
    }" \
    --output none
  ok "Apply federated credential created (entity: environment:production)."
fi

# ---------------------------------------------------------------------------
# Step 6: Role Assignments
# ---------------------------------------------------------------------------
info "Step 6/6: Assigning roles to the Terraform service principal..."

SP_OBJECT_ID=$(az ad sp show --id "${CLIENT_ID}" --query "id" -o tsv)

# Owner at Tenant Root Management Group
ROOT_MG_SCOPE="/providers/Microsoft.Management/managementGroups/${TENANT_ID}"

existing_owner=$(az role assignment list \
  --scope "${ROOT_MG_SCOPE}" \
  --role "Owner" \
  --assignee-object-id "${SP_OBJECT_ID}" \
  --query "[0].id" -o tsv 2>/dev/null || true)

if [[ -n "${existing_owner}" ]]; then
  ok "Owner role at root management group already assigned — skipping."
else
  run az role assignment create \
    --role "Owner" \
    --assignee-object-id "${SP_OBJECT_ID}" \
    --assignee-principal-type "ServicePrincipal" \
    --scope "${ROOT_MG_SCOPE}" \
    --output none
  ok "Owner role assigned at tenant root management group."
fi

# Storage Blob Data Contributor on state storage account (for OIDC-based backend)
SA_RESOURCE_ID=$(az storage account show \
  --name "${STATE_SA_NAME}" \
  --resource-group "${STATE_RG}" \
  --query "id" -o tsv)

existing_blob_role=$(az role assignment list \
  --scope "${SA_RESOURCE_ID}" \
  --role "Storage Blob Data Contributor" \
  --assignee-object-id "${SP_OBJECT_ID}" \
  --query "[0].id" -o tsv 2>/dev/null || true)

if [[ -n "${existing_blob_role}" ]]; then
  ok "Storage Blob Data Contributor already assigned — skipping."
else
  run az role assignment create \
    --role "Storage Blob Data Contributor" \
    --assignee-object-id "${SP_OBJECT_ID}" \
    --assignee-principal-type "ServicePrincipal" \
    --scope "${SA_RESOURCE_ID}" \
    --output none
  ok "Storage Blob Data Contributor assigned on state storage account."
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "  Bootstrap Complete — Add These as GitHub Secrets"
echo "============================================================"
echo ""
echo "  Secret Name                  Value"
echo "  ---------------------------  ----------------------------------"
printf "  %-28s %s\n" "AZURE_CLIENT_ID"      "${CLIENT_ID}"
printf "  %-28s %s\n" "AZURE_TENANT_ID"      "${TENANT_ID}"
printf "  %-28s %s\n" "AZURE_SUBSCRIPTION_ID" "${SUBSCRIPTION_ID}"
printf "  %-28s %s\n" "BACKEND_STORAGE_ACCOUNT" "${STATE_SA_NAME}"
echo ""
echo "  Also update bootstrap/backend.tf with:"
echo "    storage_account_name = \"${STATE_SA_NAME}\""
echo "    resource_group_name  = \"${STATE_RG}\""
echo ""
echo "  Next steps:"
echo "    1. Set the GitHub secrets listed above"
echo "    2. Create a GitHub environment named 'production' with required approvers"
echo "    3. Update bootstrap/terraform.tfvars (from terraform.tfvars.example)"
echo "    4. Run: make init && make plan && make apply"
echo "============================================================"
