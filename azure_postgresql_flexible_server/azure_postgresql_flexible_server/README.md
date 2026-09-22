# Azure Government PostgreSQL Flexible Server Terraform Module

Terraform module for deploying and managing **Azure Database for PostgreSQL Flexible Server in Azure Government** with support for secure private networking, Microsoft Entra authentication, customer-managed keys (CMK), read replicas, monitoring, backup integration, governance, and Active/Passive disaster recovery.

The module follows a consistent enterprise pattern for optional resources:

- **CREATE NEW** — set the corresponding `create_*` flag to `true` and provide the required creation inputs.
- **USE EXISTING** — keep the `create_*` flag `false` and provide the corresponding `existing_*_id` or resource reference.
- **NOT CONFIGURED** — keep the create flag disabled and leave the existing resource input unset.

This allows the same module to support greenfield deployments, existing enterprise platform services, and partially managed environments without forcing creation of every optional component.

---

## 1. Supported architecture

### Default regional model

| Capability | Primary region | DR region |
|---|---|---|
| Azure Government region | `USGov Virginia` | `USGov Texas` |
| PostgreSQL role | Primary Flexible Server | Read replica or standalone secondary |
| Default DR pattern | Active | Passive |
| Networking | Public, Private Endpoint, or VNet Integration | Public, Private Endpoint, or VNet Integration |
| Private Endpoint | Supported | Supported |
| PostgreSQL Private DNS | Supported | Supported |
| Managed identity | Primary UAMI / System Assigned | DR UAMI / System Assigned |
| CMK | Primary regional key | DR regional key |
| Key Vault | Primary regional vault | DR regional vault |
| Key Vault Private Endpoint | Supported | Supported |
| Key Vault Private DNS | Supported | Supported |
| CMK RBAC | Primary UAMI → Primary Key Vault | DR UAMI → DR Key Vault |
| DR replication | Source | Asynchronous read replica |
| CREATE / USE EXISTING / NOT CONFIGURED | Supported | Supported |

> Azure Government service capabilities vary by subscription, region, SKU, and time. Validate PostgreSQL SKUs, availability zones, HA modes, backup capabilities, and related platform features before deployment.

---

## 2. Current tested Virginia baseline

The current validated Virginia test configuration uses:

```text
USGov Virginia
│
├── PostgreSQL Flexible Server - Primary
│   ├── PostgreSQL 16
│   ├── General Purpose
│   ├── Private Endpoint
│   ├── Private DNS
│   ├── Password + Microsoft Entra authentication
│   ├── System Assigned + User Assigned Managed Identity
│   ├── Customer-Managed Key
│   ├── SameZone HA
│   ├── Diagnostic Settings
│   └── Azure Monitor metric alerts
│
├── Read Replica 01
│   ├── Private Endpoint
│   ├── CMK/UAMI
│   └── Diagnostic Settings
│
└── Read Replica 02
    ├── Private Endpoint
    ├── CMK/UAMI
    └── Diagnostic Settings
```

The tested subscription currently exposes only Availability Zone `1` for `Standard_D2s_v3` / `GP_Standard_D2s_v3` in `USGov Virginia`, so the current test deployment places the primary and same-region read replicas in Zone 1.

Use `scripts/feature-inventory.ps1` before deployment to validate current subscription-specific capabilities.

---

## 3. Core deployment topologies

### Primary only

```hcl
create_primary_server   = true
create_dr_replica       = false
create_secondary_server = false
```

Result:

```text
Primary PostgreSQL
```

### Primary with additional read replicas

```hcl
create_primary_server = true

additional_read_replicas = {
  replica_01 = {
    name                = "<replica-name>"
    resource_group_name = "<resource-group>"
    location            = "USGov Virginia"
    networking_mode     = "private_endpoint"
  }
}
```

The module supports multiple direct read replicas, subject to Azure PostgreSQL Flexible Server service limits.

### Active/Passive cross-region DR

```hcl
create_primary_server   = true
create_dr_replica       = true
create_secondary_server = false
```

Result:

```text
USGov Virginia
Primary / Writer
       |
       | Asynchronous replication
       v
USGov Texas
Passive Read Replica
```

### Standalone secondary

```hcl
create_primary_server   = false
create_dr_replica       = false
create_secondary_server = true
```

or deploy two independent writable servers:

```hcl
create_primary_server   = true
create_dr_replica       = false
create_secondary_server = true
```

Two independent writable servers are **not** a native multi-region Active/Active PostgreSQL pair.

### Use existing primary or DR server

```hcl
create_primary_server      = false
existing_primary_server_id = "/subscriptions/.../Microsoft.DBforPostgreSQL/flexibleServers/<primary>"

create_dr_replica       = false
create_secondary_server = false
existing_dr_server_id   = "/subscriptions/.../Microsoft.DBforPostgreSQL/flexibleServers/<dr>"
```

Existing servers are referenced read-only unless explicitly imported into Terraform state. Creation-time properties of an existing server are not automatically taken over by the module.

---

## 4. CREATE / USE EXISTING / NOT CONFIGURED pattern

### CREATE NEW

```hcl
create_primary_key_vault = true
primary_key_vault_name   = "<unique-name>"
```

### USE EXISTING

```hcl
create_primary_key_vault      = false
existing_primary_key_vault_id = "/subscriptions/.../Microsoft.KeyVault/vaults/<vault>"
```

### NOT CONFIGURED

```hcl
create_primary_key_vault      = false
existing_primary_key_vault_id = null
```

The `deployment_mode` output summarizes how major resources are being handled.

Example:

```text
primary_server                     = created
primary_network                    = existing
primary_key_vault                  = created
primary_key_vault_key              = existing
primary_key_vault_private_endpoint = created
primary_cmk_rbac                   = managed
dr_server                          = not-configured
log_analytics                      = created
monitor_action_group               = created
```

---

## 5. Module file structure

Recommended repository structure:

```text
azure_postgresql_flexible_server/
│
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── README.md
├── .gitignore
├── .terraform.lock.hcl
│
├── sample/
│   └── virginia.tfvars.example
│
├── scripts/
│   ├── create-on-demand-backup.ps1
│   ├── deploy.ps1
│   ├── dr-failback.ps1
│   ├── dr-failover.ps1
│   ├── dr-promote.ps1
│   ├── dr-status.ps1
│   ├── feature-inventory.ps1
│   ├── install-extensions.ps1
│   ├── test-private-connectivity.ps1
│   └── validate.ps1
│
├── docs/
│   └── DR_RUNBOOK.md
│
└── test/
    └── <Terraform / Go tests>
```

Generated runtime files such as `.terraform/`, `*.tfplan`, `terraform.tfstate.backup`, and diagnostic logs should not be committed.

The current development workflow uses a local state file named:

```text
terraform.tfstate
```

Do not delete the active state file unless the deployment has intentionally been migrated to another backend.

---

## 6. Terraform and provider requirements

Current module baseline:

```text
Terraform   >= 1.9.8, < 2.0.0
AzureRM     = 4.81.0
AzAPI       = 2.12.0
Environment = Azure Government
```

The providers are configured for:

```hcl
environment = "usgovernment"
```

Required resource providers can include:

```text
Microsoft.DBforPostgreSQL
Microsoft.Network
Microsoft.Insights
Microsoft.OperationalInsights
Microsoft.ManagedIdentity
Microsoft.KeyVault
Microsoft.DataProtection
Microsoft.Security
```

Use:

```powershell
.\scripts\validate.ps1
```

to perform module and provider validation.

---

## 7. Authentication

The module supports PostgreSQL password authentication and Microsoft Entra authentication.

Example:

```hcl
authentication = {
  password_auth_enabled         = true
  active_directory_auth_enabled = true
  tenant_id                     = "<tenant-id>"
}

administrator_login = "pgadminuser"
```

Never commit the PostgreSQL administrator password to a `.tfvars` file.

Use:

```powershell
$env:TF_VAR_administrator_password = "<secret>"
```

or an approved CI/CD secret store.

### Microsoft Entra administrators

```hcl
entra_administrators = {
  database_admins = {
    object_id      = "<object-id>"
    principal_name = "<group-or-user-name>"
    principal_type = "Group"
  }
}
```

For read replicas, Microsoft Entra authentication configuration is inherited through the replication topology; the module does not independently create separate Entra administrator objects for each additional read replica.

---

## 8. PostgreSQL compute, storage, HA, and backup

Example primary configuration:

```hcl
postgresql_version = "16"

sku_name   = "GP_Standard_D2s_v3"
storage_mb = 131072

auto_grow_enabled      = true
backup_retention_days  = 7
primary_zone           = "1"

primary_high_availability = {
  mode                      = "SameZone"
  standby_availability_zone = "1"
}
```

Availability zones are subscription and SKU specific.

Validate before deployment:

```powershell
.\scripts\feature-inventory.ps1 `
  -SubscriptionId "<subscription-id>" `
  -PrimaryRegion "usgovvirginia" `
  -DrRegion "usgovtexas" `
  -SkuName "Standard_D2s_v3"
```

Do not assume Zone 2, Zone 3, or ZoneRedundant HA is available simply because the Azure region is generally zonal.

---

## 9. Networking modes

The module supports:

```text
private_endpoint
vnet_integration
public
```

### Private Endpoint mode

```hcl
networking_mode = "private_endpoint"
```

When Private Endpoint mode is selected, PostgreSQL public network access is disabled by the module.

Typical existing subnet input:

```hcl
primary_private_endpoint_subnet_id = "/subscriptions/.../subnets/<subnet>"
```

### VNet Integration mode

```hcl
networking_mode = "vnet_integration"
```

Requires:

- a delegated subnet; and
- a VNet-integration Private DNS zone.

### Public mode

```hcl
networking_mode = "public"
```

Firewall rules can be supplied through `firewall_rules`.

---

## 10. PostgreSQL Private DNS

Azure Government PostgreSQL Private Link uses:

```text
privatelink.postgres.database.usgovcloudapi.net
```

VNet Integration uses a different DNS model and requires a zone ending in:

```text
.postgres.database.azure.com
```

Do not combine the Private Link and VNet Integration DNS patterns.

---

## 11. Private Endpoints

The module supports:

- Primary PostgreSQL Private Endpoint
- DR PostgreSQL Private Endpoint
- Additional read-replica Private Endpoints
- Primary Key Vault Private Endpoint
- DR Key Vault Private Endpoint

Example:

```hcl
create_primary_private_endpoint = true

primary_private_endpoint_name = "<postgresql-pe-name>"

primary_private_endpoint_subnet_id = "/subscriptions/.../subnets/<subnet>"

private_endpoint_attach_dns_zone = true
```

Use:

```powershell
.\scripts\test-private-connectivity.ps1 `
  -HostName "<postgresql-private-fqdn>" `
  -Port 5432
```

from a network location that can resolve and reach the Private Endpoint.

---

## 12. Enterprise CMK architecture

The module maintains independent Primary and DR encryption stacks.

```text
USGov Virginia                                  USGov Texas

Primary PostgreSQL                              DR PostgreSQL
       |                                               |
       v                                               v
Primary UAMI                                      DR UAMI
       |                                               |
       v                                               v
Primary Key Vault RBAC                           DR Key Vault RBAC
       |                                               |
       v                                               v
Primary Key Vault                                DR Key Vault
       |                                               |
       v                                               v
Primary CMK                                      DR CMK
```

A Primary PostgreSQL server does not fall back to the DR key, and a DR PostgreSQL server does not fall back to the Primary key.

### Primary CMK example

```hcl
primary_customer_managed_key = {
  key_vault_key_id = "<primary-key-uri>"

  primary_user_assigned_identity_id = "<primary-uami-resource-id>"
}
```

### DR CMK example

```hcl
dr_customer_managed_key = {
  key_vault_key_id = "<dr-key-uri>"

  primary_user_assigned_identity_id = "<dr-uami-resource-id>"
}
```

The property name `primary_user_assigned_identity_id` is the AzureRM provider field name used inside the CMK block, including for the DR server.

---

## 13. Regional Key Vault security

Module-created CMK Key Vaults use enterprise-oriented controls:

- RBAC authorization enabled
- Purge protection enabled
- Public network access disabled
- Default-deny network ACL
- Private Endpoint support
- Azure Government Private DNS support

Azure Government Key Vault Private DNS:

```text
privatelink.vaultcore.usgovcloudapi.net
```

CMK RBAC uses:

```text
Key Vault Crypto Service Encryption User
```

for the PostgreSQL UAMI.

---

## 14. Existing private Key Vault and key

If Terraform cannot reach the private Key Vault data plane, use an existing key rather than forcing Terraform to create it.

Example:

```hcl
create_primary_key_vault_key = false

existing_primary_key_vault_key_id = "https://<vault>.vault.usgovcloudapi.net/keys/<key>"
```

A versionless key URI can be used where appropriate for key rotation.

Avoid adding a Key Vault key data source solely to read a private key when the Terraform runner has no route to the Key Vault data plane.

---

## 15. Read replicas

Additional read replicas are configured through:

```hcl
additional_read_replicas = {
  replica_01 = {
    name                = "<replica-name>"
    resource_group_name = "<resource-group>"
    location            = "USGov Virginia"

    networking_mode = "private_endpoint"

    sku_name          = "GP_Standard_D2s_v3"
    storage_mb        = 131072
    auto_grow_enabled = true
    zone              = "1"

    system_assigned_identity_enabled = true
    user_assigned_identity_id        = "<uami-resource-id>"

    key_vault_key_id = "<cmk-key-uri>"

    create_private_endpoint          = true
    private_endpoint_name            = "<replica-pe-name>"
    private_endpoint_subnet_id       = "<subnet-resource-id>"
    private_endpoint_attach_dns_zone = true

    enable_diagnostics = true
  }
}
```

Important behavior:

- Read replicas are read-only while replication is active.
- HA standby nodes are not readable replicas.
- Read replicas can be promoted.
- Promotion changes the topology outside Terraform and requires state/configuration review.
- Additional read replicas can have their own Private Endpoints and diagnostic settings.
- Same-region replicas can reuse the regional CMK/UAMI where that matches the security design.
- Cross-region DR should use the independent DR regional CMK stack.

---

## 16. Virtual endpoints and DR

Virtual endpoints provide role-based writer/reader endpoints for a PostgreSQL primary/read-replica topology.

They are especially important for planned `SwitchOver` operations.

Before DR testing, configure and validate:

```text
Writer Virtual Endpoint
Reader Virtual Endpoint
```

Detailed failover/failback procedures are documented in:

```text
docs/DR_RUNBOOK.md
```

The supported DR model is Active/Passive. Azure PostgreSQL Flexible Server does not provide native multi-region multi-writer Active/Active through this read-replica architecture.

---

## 17. Databases, parameters, and extensions

### Databases

```hcl
database_definitions = {
  appdb = {
    charset   = "UTF8"
    collation = "en_US.utf8"
  }
}
```

### PostgreSQL parameters

Use:

```hcl
server_parameters = {}
primary_server_parameter_overrides = {}
dr_server_parameter_overrides = {}
```

as required.

### Extensions

Terraform manages the Azure PostgreSQL extension allowlist through:

```hcl
extensions = [
  "uuid-ossp",
  "pg_stat_statements"
]
```

Allowlisting an extension does **not** install it inside a database.

Use:

```powershell
.\scripts\install-extensions.ps1
```

to connect with `psql` and execute:

```sql
CREATE EXTENSION IF NOT EXISTS ...
```

for the target database.

---

## 18. Query Store, logging, and PgBouncer

Optional PostgreSQL features include:

- Query Store
- Autonomous tuning
- PostgreSQL server logging
- PgBouncer
- Generic server parameters

Example logging configuration:

```hcl
logging = {
  log_connections            = true
  log_disconnections         = true
  log_checkpoints            = true
  log_min_duration_statement = 1000
}
```

Unset optional blocks remain unmanaged.

---

## 19. Monitoring and diagnostics

The module supports:

- Create or use an existing Log Analytics Workspace
- Primary PostgreSQL diagnostic settings
- DR PostgreSQL diagnostic settings
- Additional read-replica diagnostic settings
- Dynamic discovery of supported diagnostic categories
- Storage Account diagnostic destination
- Event Hub diagnostic destination
- Azure Monitor metric alerts
- Azure Monitor Action Group creation or reuse
- Azure Monitor Workbook creation or reuse

Example:

```hcl
create_log_analytics_workspace = true

log_analytics_workspace_name                = "<workspace-name>"
log_analytics_resource_group_name           = "<resource-group>"
log_analytics_location                      = "USGov Virginia"
log_analytics_retention_days                = 30

enable_primary_diagnostics = true
enable_dr_diagnostics      = false

diagnostic_log_categories    = []
diagnostic_metric_categories = []
```

Empty diagnostic category collections instruct the module to discover supported categories dynamically.

---

## 20. Azure Monitor metric alerts

Current `metric_alerts` targets support:

```text
primary
dr
```

Example:

```hcl
metric_alerts = {
  primary_high_cpu = {
    target                   = "primary"
    metric_name              = "cpu_percent"
    aggregation              = "Average"
    operator                 = "GreaterThan"
    threshold                = 80
    severity                 = 2
    frequency                = "PT5M"
    window_size              = "PT15M"
    use_default_action_group = true
  }
}
```

The tested Primary baseline currently includes alert rules for:

```text
is_db_alive
cpu_percent
memory_percent
storage_percent
```

Additional supported PostgreSQL metrics can be added after confirming availability in Azure Government.

Replica diagnostic settings are currently supported. Replica metric-alert targeting should only be enabled after extending `metric_alerts` to resolve additional replica resource IDs.

---

## 21. Action Group

The module can create one default Action Group and attach it to multiple metric alerts.

Example:

```hcl
create_monitor_action_group      = true
existing_monitor_action_group_id = null

monitor_action_group_name                = "ag-<environment>-postgresql"
monitor_action_group_resource_group_name = "<resource-group>"
monitor_action_group_short_name          = "pg-alerts"
monitor_action_group_location            = "global"
monitor_action_group_enabled             = true

action_group_email_receivers = {
  dbops = {
    email_address           = "<operations-email>"
    use_common_alert_schema = true
  }
}

action_group_sms_receivers     = {}
action_group_webhook_receivers = {}
```

Alert rules can use:

```hcl
use_default_action_group = true
```

to attach the module-managed/default Action Group.

---

## 22. Defender for Cloud

Optional management includes:

- Subscription-level Defender plan for `OpenSourceRelationalDatabases`
- Primary PostgreSQL advanced threat protection
- DR PostgreSQL advanced threat protection

Defender inputs default to `null`, which means Terraform does not take ownership unless explicitly requested.

This protects against accidental changes to subscription-wide security settings.

---

## 23. Native backup and Azure Backup / LTR

The module supports native PostgreSQL backup configuration and optional Azure Data Protection resources for long-term retention.

Supported Azure Backup/LTR components include:

- Backup Vault
- PostgreSQL Flexible Server backup policy
- PostgreSQL backup instance
- Backup Vault identity role assignments

The primary server is the normal LTR protection target.

Required role pattern:

```text
Backup Vault Managed Identity
        |
        +--> Reader on PostgreSQL Resource Group
        |
        +--> PostgreSQL Flexible Server Long Term Retention Backup Role
             on PostgreSQL server
```

### On-demand backup

Terraform can manage on-demand backups through `on_demand_backups`.

For operational/manual execution use:

```powershell
.\scripts\create-on-demand-backup.ps1
```

Do not create the same named backup simultaneously through both Terraform and the script.

---

## 24. Governance

Optional governance capabilities include:

- PostgreSQL management locks
- Generic RBAC assignments
- Resource tags
- Azure Advisor recommendation suppressions

RBAC aliases include effective resources such as:

```text
primary_server
dr_server
private_dns_zone
log_analytics
primary_key_vault
dr_key_vault
backup_vault
action_group
```

or a full Azure resource ID where supported.

---

## 25. Important outputs

### Deployment and topology

```text
deployment_mode
deployment_type
topology
feature_state
```

### PostgreSQL

```text
primary_server_id
primary_server_name
primary_fqdn
dr_server_id
dr_server_name
dr_fqdn
additional_read_replica_ids
```

### Networking

```text
primary_vnet_id
dr_vnet_id
primary_private_endpoint_id
primary_private_endpoint_ip
dr_private_endpoint_id
dr_private_endpoint_ip
private_dns_zone_id
vnet_integration_private_dns_zone_id
```

### Identity and CMK

```text
primary_user_assigned_identity_id
dr_user_assigned_identity_id
primary_key_vault_id
dr_key_vault_id
primary_key_vault_key_id
dr_key_vault_key_id
primary_effective_cmk_key_id
dr_effective_cmk_key_id
primary_cmk_role_assignment_id
dr_cmk_role_assignment_id
```

### Monitoring and backup

```text
log_analytics_workspace_id
monitor_action_group_id
monitor_workbook_id
backup_vault_id
backup_policy_id
ltr_backup_instance_id
defender_management
```

---

## 26. Deployment workflow

### 1. Authenticate to Azure Government

```powershell
az cloud set --name AzureUSGovernment
az login
az account set --subscription "<subscription-id>"
```

### 2. Supply PostgreSQL password when required

```powershell
$env:TF_VAR_administrator_password = "<secret>"
```

### 3. Initialize

```powershell
terraform init
```

### 4. Format

```powershell
terraform fmt -recursive
```

### 5. Validate

```powershell
terraform validate
```

or:

```powershell
.\scripts\validate.ps1
```

### 6. Validate service capability

```powershell
.\scripts\feature-inventory.ps1 `
  -SubscriptionId "<subscription-id>" `
  -PrimaryRegion "usgovvirginia" `
  -DrRegion "usgovtexas" `
  -SkuName "Standard_D2s_v3"
```

### 7. Plan

```powershell
terraform plan `
  -var-file="sample/virginia.tfvars" `
  -out="tfplan"
```

Review the plan carefully for:

```text
Unexpected resource replacement
Unexpected destroy
PostgreSQL replacement
Key Vault replacement
Private Endpoint replacement
DNS replacement
CMK replacement
State drift
```

### 8. Apply

For the current local-state development workflow:

```powershell
terraform apply `
  -backup=- `
  "tfplan"
```

`-backup=-` prevents Terraform from creating a local `terraform.tfstate.backup` file.

### 9. Clean saved plan

After a successful apply:

```powershell
Remove-Item ".\tfplan" -ErrorAction SilentlyContinue
```

---

## 27. Deployment script

The updated deployment helper can be used instead of manually running init/plan/apply.

```powershell
.\scripts\deploy.ps1
```

The script:

- initializes the configured backend;
- validates the module;
- creates a Terraform plan;
- applies the reviewed plan;
- uses `-backup=-` for the local-state workflow; and
- removes stale plan files after successful deployment.

Review script parameters before using it in CI/CD.

---

## 28. Operational scripts

| Script | Purpose |
|---|---|
| `deploy.ps1` | Terraform deployment workflow |
| `validate.ps1` | Terraform/provider/module validation |
| `feature-inventory.ps1` | PostgreSQL SKU and availability-zone capability validation |
| `test-private-connectivity.ps1` | DNS and TCP Private Endpoint connectivity testing |
| `install-extensions.ps1` | Install allowlisted PostgreSQL extensions inside a database |
| `create-on-demand-backup.ps1` | Create an operational PostgreSQL on-demand backup |
| `dr-status.ps1` | Display PostgreSQL DR, HA, replica, virtual endpoint, and optional metric status |
| `dr-promote.ps1` | Promote a PostgreSQL read replica |
| `dr-failover.ps1` | Planned/forced DR failover to the DR region |
| `dr-failback.ps1` | Planned failback to the original primary region |

Each script contains comment-based help at the top describing its purpose and usage.

---

## 29. DR operational safety

Failover and failback modify PostgreSQL replication roles directly in Azure.

After any promotion or switchover:

```text
Do not immediately run terraform apply
```

First:

1. Review the actual Azure topology.
2. Review Terraform state.
3. Update configuration if roles changed.
4. Run `terraform plan`.
5. Confirm there is no unintended destroy or replacement.
6. Apply only after reconciliation.

See:

```text
docs/DR_RUNBOOK.md
```

for full procedures.

---

## 30. Production validation checklist

Before production deployment verify:

- [ ] Azure Government cloud is selected.
- [ ] Correct subscription and tenant are selected.
- [ ] Required Azure resource providers are registered.
- [ ] Required PostgreSQL SKU is supported.
- [ ] Required availability zones are supported for the subscription/SKU.
- [ ] Intended HA mode is supported.
- [ ] Primary and DR resource groups are correct.
- [ ] VNet and subnet IDs are correct.
- [ ] PostgreSQL Private DNS resolution works.
- [ ] PostgreSQL Private Endpoints are healthy.
- [ ] Key Vault Private DNS resolves correctly.
- [ ] Terraform runner connectivity to private Key Vaults is understood.
- [ ] Primary UAMI has the intended Primary Key Vault CMK role.
- [ ] DR UAMI has the intended DR Key Vault CMK role.
- [ ] Primary and DR CMKs are independent for cross-region DR.
- [ ] Key Vault purge protection is enabled.
- [ ] Key Vault public network access is disabled.
- [ ] Key Vault network ACL default action is `Deny`.
- [ ] PostgreSQL authentication configuration is correct.
- [ ] Administrator password is supplied securely.
- [ ] Entra administrators are correct.
- [ ] Read replicas are healthy.
- [ ] Private Endpoint DNS zone groups are correct.
- [ ] Diagnostic Settings are enabled where required.
- [ ] Log Analytics destination is correct.
- [ ] Metric alerts are enabled.
- [ ] Action Group destinations are correct.
- [ ] Native backup retention is correct.
- [ ] Azure Backup/LTR configuration is reviewed if enabled.
- [ ] DR replication has been tested.
- [ ] Planned failover/failback has been tested.
- [ ] `terraform output deployment_mode` matches the intended design.
- [ ] `terraform output feature_state` matches the intended design.
- [ ] `terraform output topology` matches the intended design.
- [ ] `terraform plan` contains no unexpected destroy or replacement.

---

## 31. Security design summary

The enterprise security model is designed around:

```text
Private PostgreSQL connectivity
Private Key Vault connectivity
No public access to module-created CMK Key Vaults
RBAC-authorized Key Vaults
Purge protection
Customer-managed PostgreSQL encryption
Independent Primary/DR regional CMKs
Managed identities
Microsoft Entra authentication
Private DNS
Azure Monitor diagnostics
Defender integration where explicitly enabled
Terraform-managed governance controls
```

The module intentionally maintains clear separation between Primary and DR regional encryption dependencies while preserving the CREATE / USE EXISTING / NOT CONFIGURED operating model.

---

## 32. State and repository hygiene

For the current local-backend development workflow:

### Keep locally

```text
terraform.tfstate
sample/virginia.tfvars
```

### Commit

```text
*.tf
README.md
.gitignore
.terraform.lock.hcl
sample/*.tfvars.example
scripts/
docs/
test/
```

### Do not commit

```text
.terraform/
*.tfstate
*.tfstate.*
*.tfplan
tfplan
*.log
*.tfvars
```

Example `.gitignore`:

```gitignore
.terraform/

*.tfstate
*.tfstate.*

*.tfplan
tfplan

*.tfvars
!*.tfvars.example
!sample/*.tfvars.example

*.log

.terraformrc
terraform.rc
```

Do not ignore `.terraform.lock.hcl`.

---

## 33. Notes

- Existing resources supplied by ID remain externally created resources unless explicitly imported into Terraform state.
- Some PostgreSQL properties are creation-time or replacement-sensitive properties.
- Customer-managed encryption changes can cause PostgreSQL replacement depending on provider/service behavior; always inspect the plan.
- A Private Key Vault data plane requires network reachability from the Terraform runner if Terraform creates or reads keys.
- Additional read replicas are not writable while replication is active.
- Same-region read replicas are not equivalent to HA standby nodes.
- DR read replicas use asynchronous replication.
- Forced DR promotion can result in data loss equal to outstanding replication lag.
- Azure Government capability varies by region, subscription, and SKU.
- Always run `terraform fmt`, `terraform validate`, and a reviewed `terraform plan` before applying changes.
