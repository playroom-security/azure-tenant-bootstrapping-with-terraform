<<<<<<< HEAD
# azure-tenant-bootstrapping-with-terraform
This script contains the baseline configurations to deploy a bootstrapped azure tenant infrastructure with Terraform
=======
<<<<<<< HEAD
# azure-tenant-bootstrapping-with-terraform
This script contains the baseline configurations to deploy a bootstrapped azure tenant infrastructure with Terraform
=======
# Azure Tenant Bootstrap — CAF Enterprise Scale

A production-grade Terraform codebase that bootstraps an Azure tenant following Microsoft's [Cloud Adoption Framework (CAF) Enterprise Scale](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/landing-zone/) landing zone pattern. All future Azure resource deployments flow through Terraform, executed by GitHub Actions using OIDC authentication (no long-lived secrets).

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Management Group Hierarchy](#management-group-hierarchy)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
  - [Step 1 — Run the Bootstrap Script](#step-1--run-the-bootstrap-script)
  - [Step 2 — Configure GitHub](#step-2--configure-github)
  - [Step 3 — Update Backend Configuration](#step-3--update-backend-configuration)
  - [Step 4 — Configure Terraform Variables](#step-4--configure-terraform-variables)
  - [Step 5 — Deploy](#step-5--deploy)
- [GitHub Actions Workflows](#github-actions-workflows)
- [Module Reference](#module-reference)
- [Adding Landing Zone Workloads](#adding-landing-zone-workloads)
- [Personal GitHub Account vs Organisation](#personal-github-account-vs-organisation)
- [Security Considerations](#security-considerations)
- [Troubleshooting](#troubleshooting)

---

## Architecture Overview

The bootstrap follows a strict dependency chain to solve the "bootstrap paradox" (Terraform needs state storage, but Terraform manages state storage):

```
Step 1  scripts/bootstrap.sh    Azure CLI — runs once, no Terraform
        └─ State storage account, App Registration, OIDC federation, root RBAC

Step 2  bootstrap/              Terraform root — tenant-level foundations
        └─ Management groups, policies, RBAC, logging, budgets

Step 3  environments/prod/      Terraform root — production landing zone workloads
Step 4  environments/nonprod/   Terraform root — non-production landing zone workloads
```

### What Gets Deployed

| Component | Tool | Description |
|---|---|---|
| State storage account | Azure CLI (`bootstrap.sh`) | Blob storage for all Terraform remote state |
| App Registration + Service Principal | Azure CLI (`bootstrap.sh`) | Identity that Terraform and GitHub Actions use |
| OIDC federated credentials | Azure CLI (`bootstrap.sh`) | Keyless auth from GitHub Actions to Azure |
| Management group hierarchy | Terraform | CAF enterprise-scale MG structure |
| Azure Policy assignments | Terraform | Governance guardrails at each MG scope |
| RBAC role assignments | Terraform | Group-based access control at MG scope |
| Log Analytics workspace | Terraform | Centralised log sink for the platform |
| Budget alerts | Terraform | Cost management with email notifications |

---

## Management Group Hierarchy

```
Tenant Root Group
├── {prefix}-platform
│   ├── {prefix}-platform-management      ← Management subscription lives here
│   ├── {prefix}-platform-connectivity    ← Hub networking subscription lives here
│   └── {prefix}-platform-identity        ← Entra ID / Domain Services lives here
├── {prefix}-landingzones
│   ├── {prefix}-landingzones-corp         ← Production workload subscriptions
│   └── {prefix}-landingzones-corpnonprod  ← Non-production workload subscriptions
├── {prefix}-sandbox                       ← Free-form experimentation
└── {prefix}-decommissioned                ← Subscriptions being retired
```

### Policy Assignments by Scope

| Policy | Scope | Effect |
|---|---|---|
| Require tag: `environment` | Root | Deny |
| Require tag: `owner` | Root | Deny |
| Require tag: `cost-center` | Root | Deny |
| Allowed locations | Root | Deny |
| Allowed locations (resource groups) | Root | Deny |
| Require HTTPS on storage accounts | Landing Zones | Deny |
| Audit unencrypted OS disks | Landing Zones | Audit |
| Deny public IP address creation | Corp (Production) | Deny |
| Enable Microsoft Defender for Cloud | Platform Management | DeployIfNotExists |

---

## Repository Structure

```
Bootstrap-Azure-Terraform/
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml       # PR-triggered: fmt → validate → plan → PR comment
│       └── terraform-apply.yml      # main-push: environment-gated apply
├── .gitignore
├── Makefile                         # Developer convenience targets
├── README.md
│
├── scripts/
│   └── bootstrap.sh                 # One-time idempotent pre-Terraform setup
│
├── bootstrap/                       # Root module — tenant-level foundations
│   ├── versions.tf                  # Provider version constraints
│   ├── providers.tf                 # azurerm + azuread (OIDC, no secrets)
│   ├── backend.tf                   # Azure Blob remote state
│   ├── locals.tf                    # Naming convention + common tags
│   ├── main.tf                      # Module orchestration
│   ├── variables.tf                 # Input variable definitions
│   ├── outputs.tf                   # Outputs consumed by environment roots
│   └── terraform.tfvars.example    # Template — copy to terraform.tfvars
│
├── environments/
│   ├── prod/                        # Production landing zone root
│   │   ├── backend.tf
│   │   ├── providers.tf
│   │   ├── versions.tf
│   │   ├── main.tf                  # Reads bootstrap outputs, add workload modules here
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   └── nonprod/                     # Non-production landing zone root (same structure)
│
└── modules/
    ├── management-groups/           # CAF MG hierarchy
    ├── policy/                      # Built-in policy assignments
    ├── rbac/                        # Role assignments at MG scope
    ├── logging/                     # Log Analytics workspace + diagnostics
    └── budget/                      # Subscription budget alerts
```

---

## Prerequisites

### Local Tools

| Tool | Minimum Version | Install |
|---|---|---|
| Azure CLI | 2.55.0 | `brew install azure-cli` |
| Terraform | 1.7.0 | `brew tap hashicorp/tap && brew install hashicorp/tap/terraform` |
| jq | 1.6 | `brew install jq` |
| GNU coreutils (macOS) | any | `brew install coreutils` |

### Azure Requirements

- An active **Entra ID tenant**
- At least one **Azure subscription** to use as the management/platform subscription
- Your account must have:
  - **Global Administrator** role in Entra ID (to create App Registrations and federated credentials)
  - **Owner** on the management subscription (to create the state storage account)
  - **Management Group Contributor** at the tenant root (to create management groups and assign Owner to the service principal)

> **Tip:** If you are the person who created the Azure tenant, you already have all of these.

### GitHub Requirements

- A GitHub repository (personal account or organisation — [see note below](#personal-github-account-vs-organisation))
- Ability to set **repository secrets** (`Settings → Secrets and variables → Actions`)
- Ability to create **environments** (`Settings → Environments`)

---

## Getting Started

### Step 1 — Run the Bootstrap Script

The bootstrap script creates everything Terraform needs to run but cannot create itself.

```bash
# Clone this repo first (or initialise it locally)
git clone https://github.com/your-username/Bootstrap-Azure-Terraform.git
cd Bootstrap-Azure-Terraform

# Log in to Azure with an account that has Global Administrator + Owner
az login
az account set --subscription "<your-management-subscription-id>"

# Run the script — set your values as environment variables
GITHUB_ORG=your-github-username-or-org \
GITHUB_REPO=Bootstrap-Azure-Terraform \
PREFIX=contoso \
LOCATION=eastus \
./scripts/bootstrap.sh
```

The script will:
1. Create a resource group (`rg-terraform-state-mgmt-eastus`)
2. Create a Storage Account with versioning and soft delete enabled
3. Create three blob containers: `bootstrap`, `prod`, `nonprod`
4. Create an App Registration named `sp-terraform-bootstrap-{prefix}`
5. Create two OIDC federated credentials (plan + apply)
6. Assign **Owner** at the tenant root management group
7. Assign **Storage Blob Data Contributor** on the state storage account

At the end it prints a summary like this:

```
============================================================
  Bootstrap Complete — Add These as GitHub Secrets
============================================================

  Secret Name                  Value
  ---------------------------  ----------------------------------
  AZURE_CLIENT_ID              xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  AZURE_TENANT_ID              xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  AZURE_SUBSCRIPTION_ID        xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  BACKEND_STORAGE_ACCOUNT      contosotfstateabcd1234
============================================================
```

> **Re-running:** The script is fully idempotent. If it fails partway through, you can safely re-run it and it will skip anything that already exists.

---

### Step 2 — Configure GitHub

#### 2a. Add Repository Secrets

Go to your repository → **Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret Name | Value |
|---|---|
| `AZURE_CLIENT_ID` | Client ID printed by the bootstrap script |
| `AZURE_TENANT_ID` | Tenant ID printed by the bootstrap script |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID printed by the bootstrap script |
| `BACKEND_STORAGE_ACCOUNT` | Storage account name printed by the bootstrap script |

> These are IDs, not passwords. They are not sensitive on their own — the security comes from OIDC, where Azure validates that the request originates from your specific GitHub repository and branch/environment.

#### 2b. Create the `production` Environment

Go to your repository → **Settings → Environments → New environment**.

Name it exactly: `production`

Then configure **Protection rules**:
- Enable **Required reviewers** and add yourself (or your team)
- Optionally restrict to the `main` branch only

This gate means the apply workflow will pause and wait for a human to approve before Terraform makes any changes to Azure.

---

### Step 3 — Update Backend Configuration

Open `bootstrap/backend.tf` and replace the placeholder with the storage account name printed by the bootstrap script:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state-mgmt-eastus"
    storage_account_name = "contosotfstateabcd1234"   # ← replace this
    container_name       = "bootstrap"
    key                  = "bootstrap.tfstate"
    use_oidc             = true
  }
}
```

Do the same for `environments/prod/backend.tf` and `environments/nonprod/backend.tf` (same storage account name, different `container_name` and `key`).

---

### Step 4 — Configure Terraform Variables

```bash
cp bootstrap/terraform.tfvars.example bootstrap/terraform.tfvars
```

Edit `bootstrap/terraform.tfvars` with your values:

```hcl
# Core Identity
tenant_id                  = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
management_subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Naming & Tagging
prefix           = "contoso"          # 2-8 lowercase alphanumeric
default_location = "eastus"
cost_center      = "IT-Platform"
owner_email      = "platform@contoso.com"

# Policies
allowed_locations = ["eastus", "eastus2"]

# Set to "DoNotEnforce" on first run to audit before blocking
policy_enforcement_mode = "DoNotEnforce"

# RBAC — Entra ID group object IDs (leave as empty strings to skip)
platform_admin_group_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
developer_group_id      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Logging
log_analytics_retention_days = 90

# Budget
budget_amount_usd   = 500
budget_alert_emails = ["platform@contoso.com"]
```

> **Finding group object IDs:** Azure Portal → Microsoft Entra ID → Groups → click the group → copy the **Object ID**.

> **First run tip:** Set `policy_enforcement_mode = "DoNotEnforce"` on the first apply. This puts all Deny policies into audit mode so you can see what they would block before enforcing them. Change to `"Default"` once you are satisfied.

---

### Step 5 — Deploy

#### Option A — Via GitHub Actions (Recommended)

Push your changes to `main`, then trigger the workflows manually:

```bash
git add .
git commit -m "feat: initial CAF enterprise-scale bootstrap"
git push origin main
```

1. Go to your repository → **Actions** → **Terraform Plan** → **Run workflow**
   - Select `bootstrap` as the target, click **Run workflow**
   - Review the plan output in the run summary
2. Go to **Actions** → **Terraform Apply** → **Run workflow**
   - Select `bootstrap`, type `APPLY` in the confirmation field, click **Run workflow**
   - Approve the `production` environment gate when prompted
   - Terraform applies the changes

#### Option B — Locally (First Run / Emergency)

```bash
# Authenticate
az login
export ARM_CLIENT_ID="<client-id>"
export ARM_TENANT_ID="<tenant-id>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
export ARM_USE_OIDC=true

# Or use your personal credentials directly:
# export ARM_USE_AZURE_CLI_AUTH=true

make init
make plan
make apply
```

---

## GitHub Actions Workflows

All three workflows are triggered **manually** via GitHub's `workflow_dispatch` event. No workflow fires automatically on push or pull request.

To run any workflow: go to your repository → **Actions** tab → select the workflow → **Run workflow** → fill in the inputs → click the green **Run workflow** button.

---

### `terraform-plan.yml` — Manual Plan

**Inputs:**

| Input | Description | Options |
|---|---|---|
| `target_dir` | Which Terraform root to plan | `bootstrap`, `environments/prod`, `environments/nonprod` |

**Steps:**

| Step | What it does |
|---|---|
| `az login` | Authenticates to Azure via OIDC |
| `terraform fmt -check` | Checks formatting (non-blocking — surfaced in summary) |
| `terraform init` | Initialises backend |
| `terraform validate` | Validates configuration syntax |
| `terraform plan` | Generates a plan, saves output to the Actions run summary |
| Upload artifact | Uploads `tfplan` + `plan_output.txt` for 7 days (usable by apply) |

---

### `terraform-apply.yml` — Manual Apply

**Inputs:**

| Input | Description | Options |
|---|---|---|
| `target_dir` | Which Terraform root to apply | `bootstrap`, `environments/prod`, `environments/nonprod` |
| `confirm` | Safety confirmation — type `APPLY` exactly | free text |

The `confirm` field must contain exactly `APPLY` or the workflow fails before doing anything. After that, the `production` GitHub environment gate pauses for required reviewer approval before Terraform touches Azure.

**Steps:**

| Step | What it does |
|---|---|
| Validate confirmation | Fails immediately if `confirm` ≠ `APPLY` |
| Environment gate | Pauses for manual approval from `production` environment reviewers |
| `az login` | Authenticates via OIDC using the `environment:production` federated credential |
| `terraform init` | Initialises backend |
| `terraform plan -out=tfplan` | Generates a fresh plan |
| `terraform apply tfplan` | Applies only what was planned |
| Upload artifact | Saves apply logs for 90 days as an audit trail |

---

### `terraform-destroy.yml` — Manual Destroy

**Inputs:**

| Input | Description | Options |
|---|---|---|
| `target_dir` | Which Terraform root to destroy | `bootstrap`, `environments/prod`, `environments/nonprod` |
| `confirm` | Safety confirmation — type `DESTROY` exactly | free text |

The `confirm` field must contain exactly `DESTROY`. The `production` environment gate then pauses for reviewer approval. A destroy plan is generated and printed to the run summary before the actual destroy runs — reviewers can see exactly what will be deleted before approving.

**Steps:**

| Step | What it does |
|---|---|
| Validate confirmation | Fails immediately if `confirm` ≠ `DESTROY` |
| Environment gate | Pauses for manual approval from `production` environment reviewers |
| `az login` | Authenticates via OIDC |
| `terraform plan -destroy` | Previews all resources that will be deleted |
| Print destroy plan | Posts the full resource list to the run summary |
| `terraform apply tfplan-destroy` | Executes the destroy |
| Upload artifact | Saves destroy logs for 90 days as an audit trail |

---

## Module Reference

### `modules/management-groups`

| Input | Type | Description |
|---|---|---|
| `tenant_id` | `string` | Entra ID tenant GUID |
| `prefix` | `string` | Organisation prefix for MG names |

| Output | Description |
|---|---|
| `management_group_ids` | Map of logical names → resource IDs |
| `root_scope` | Tenant root management group scope URI |

### `modules/policy`

| Input | Type | Description |
|---|---|---|
| `tenant_id` | `string` | Tenant GUID (for root scope) |
| `management_group_ids` | `map(string)` | From management-groups module |
| `allowed_locations` | `list(string)` | Permitted Azure regions |
| `enforcement_mode` | `string` | `"Default"` or `"DoNotEnforce"` |

### `modules/rbac`

| Input | Type | Description |
|---|---|---|
| `management_group_ids` | `map(string)` | From management-groups module |
| `platform_admin_group_id` | `string` | Entra group for platform admins (optional) |
| `developer_group_id` | `string` | Entra group for developers (optional) |

### `modules/logging`

| Input | Type | Description |
|---|---|---|
| `resource_group_name` | `string` | RG for the Log Analytics workspace |
| `workspace_name` | `string` | Workspace name |
| `log_retention_days` | `number` | Retention period (30–730 days) |
| `alert_emails` | `list(string)` | Email recipients for alerts |

| Output | Description |
|---|---|
| `workspace_id` | Log Analytics workspace resource ID |
| `action_group_id` | Monitor action group resource ID |

### `modules/budget`

| Input | Type | Description |
|---|---|---|
| `subscription_id` | `string` | Subscription to attach the budget to |
| `budget_amount_usd` | `number` | Monthly limit in USD |
| `action_group_id` | `string` | Action group for notifications |

Alert thresholds: **50%**, **80%**, **100%** actual spend + **90%** forecasted spend.

---

## Adding Landing Zone Workloads

Once the bootstrap is applied, add workload infrastructure to the environment roots. They already read bootstrap outputs via `terraform_remote_state`:

```hcl
# environments/prod/main.tf

module "networking" {
  source = "../../modules/networking"   # create this module

  location            = "eastus"
  management_group_id = local.corp_mg_id
  log_analytics_id    = local.log_analytics_ws_id
}
```

The `local.bootstrap` object exposes all bootstrap outputs:

```hcl
local.bootstrap.corp_prod_management_group_id
local.bootstrap.corp_nonprod_management_group_id
local.bootstrap.log_analytics_workspace_id
local.bootstrap.action_group_id
local.bootstrap.management_group_ids   # full map
```

---

## Personal GitHub Account vs Organisation

This setup works identically with a personal GitHub account. Use your **GitHub username** where the docs say "org":

```bash
GITHUB_ORG=your-github-username ./scripts/bootstrap.sh
```

The OIDC subject claims become:
```
repo:your-github-username/Bootstrap-Azure-Terraform:pull_request
repo:your-github-username/Bootstrap-Azure-Terraform:environment:production
```

**One limitation on GitHub Free with private repos:** Environment protection rules (required approvers) are only available on public repositories under the free plan. Options:

| Approach | Cost | Notes |
|---|---|---|
| Make the repo public | Free | Fine for open-source or non-sensitive infra code |
| GitHub Pro | $4/mo | Unlocks environment gates on private repos |
| Manual `workflow_dispatch` | Free | Remove the push trigger; run apply manually via the Actions UI |

---

## Security Considerations

- **No secrets stored** — OIDC means only non-sensitive IDs (`client_id`, `tenant_id`, `subscription_id`) are in GitHub secrets. No passwords or keys.
- **Scoped OIDC credentials** — the plan credential is scoped to `pull_request` events only; the apply credential is scoped to the `production` environment only. A compromised PR cannot trigger an apply.
- **State storage hardening** — the storage account has HTTPS-only, TLS 1.2 minimum, no public blob access, shared key access disabled, blob versioning, and 30-day soft delete enabled.
- **Least privilege** — the Terraform service principal has Owner at root only during bootstrap. Workload service principals should be scoped to their specific landing zone management groups.
- **Policy guardrails** — required tags, allowed locations, and deny-public-IP policies prevent out-of-band resource creation from the moment the bootstrap applies.
- **`terraform.tfvars` is gitignored** — real values are never committed. Only `.tfvars.example` files are tracked.
- **State is remote-only** — no local state files. The `.gitignore` explicitly excludes `*.tfstate` and `*.tfstate.backup`.

---

## Troubleshooting

### `bootstrap.sh` fails: "insufficient privileges"

Your account needs **Management Group Contributor** at the tenant root to assign the Owner role. In the Azure Portal: Management Groups → your tenant root → Access control (IAM) → add yourself as Owner or Management Group Contributor.

### `terraform init` fails: "AuthorizationPermissionMismatch"

The service principal does not have **Storage Blob Data Contributor** on the state storage account. The bootstrap script assigns this automatically — re-run `scripts/bootstrap.sh` to check and fix.

### `terraform plan` fails: "does not have authorization to perform action over scope"

The service principal needs **Owner** at the tenant root management group. Verify in Azure Portal: Management Groups → Tenant Root Group → Access control (IAM).

### OIDC fails in GitHub Actions: "AADSTS70021"

The federated credential subject does not match. Common causes:
- The GitHub environment is named differently from `production` (case-sensitive)
- The repo name in the federated credential doesn't match the actual repo slug
- Re-run `scripts/bootstrap.sh` — it will check and recreate credentials if needed

### Policy assignment fails: "The policy assignment scope is invalid"

Management groups can take a few minutes to propagate after creation. If applying immediately after the management group module, add a `depends_on` or wait 60 seconds and re-run.

### Budget module fails: "`timestamp()` is not allowed"

The `timestamp()` function in `locals` is only evaluated at apply time. If you see this during `plan`, it is expected — the plan will succeed. If it fails at apply, ensure you are on Terraform >= 1.7.
>>>>>>> 44e9875 (Updated Content)
>>>>>>> d791969 (Updated Content)
