# Scenario Matrix

This document summarizes the deployment and DR scenarios supported by the Azure Government PostgreSQL Flexible Server Terraform module.

> Azure PostgreSQL capabilities are subscription-, region-, and SKU-specific. Do not assume that an HA mode or Availability Zone is supported solely because the Azure region generally advertises Availability Zone support. Validate the target subscription and SKU before deployment by using `scripts/feature-inventory.ps1`.

---

## 1. Primary Only

**Status:** Supported

Deploy only the Primary PostgreSQL Flexible Server.

```hcl
create_primary_server   = true
create_dr_replica       = false
create_secondary_server = false
```

Result:

```text
Primary PostgreSQL
```

Typical use cases:

- Single-region deployment
- Development / test
- Initial platform deployment before DR is enabled

---

## 2. Secondary Only

**Status:** Supported

Deploy a standalone writable PostgreSQL Flexible Server in the DR/secondary region.

```hcl
create_primary_server   = false
create_dr_replica       = false
create_secondary_server = true
```

This server is independent and writable.

It is **not** a read replica and does not automatically replicate data from another PostgreSQL server.

---

## 3. Primary High Availability

**Status:** Supported where Azure PostgreSQL Flexible Server supports the selected HA mode for the target subscription, region, SKU, and zone combination.

The module supports:

```text
SameZone
ZoneRedundant
```

Example:

```hcl
primary_high_availability = {
  mode                      = "SameZone"
  standby_availability_zone = "1"
}
```

or, where supported:

```hcl
primary_high_availability = {
  mode = "ZoneRedundant"
}
```

### Current tested Azure Government baseline

For the current tested `USGov Virginia` deployment using `Standard_D2s_v3` / `GP_Standard_D2s_v3`, the PostgreSQL capability API exposed only:

```text
Zone 1
```

Therefore the current tested deployment uses:

```text
SameZone HA
Primary Zone 1
Standby Zone 1
```

Do **not** assume ZoneRedundant HA is available for this current SKU/subscription without validating the capability first.

---

## 4. Secondary / Standalone DR High Availability

**Status:** Supported for a standalone writable secondary server where Azure supports the requested HA mode.

Configure with:

```hcl
dr_high_availability = {
  mode = "SameZone"
}
```

or, where supported:

```hcl
dr_high_availability = {
  mode = "ZoneRedundant"
}
```

The supported mode must be validated for the target subscription, region, SKU, and availability-zone capability.

### Important

HA is not independently configured on a PostgreSQL server while it is functioning as a read replica.

If a DR read replica is promoted to primary, HA can be enabled after promotion if supported.

---

## 5. Primary Zone Selection

**Status:** Supported

Use:

```hcl
primary_zone = "1"
```

If:

```hcl
primary_zone = null
```

Azure determines placement according to the service behavior and available capacity.

Always validate the selected zone against the PostgreSQL capability API before deployment.

---

## 6. Secondary / DR Zone Selection

**Status:** Supported

Use:

```hcl
dr_zone = "1"
```

If:

```hcl
dr_zone = null
```

Azure determines placement according to the service behavior and available capacity.

This applies to a standalone secondary server and to DR topology inputs where the Azure service allows zone selection.

---

## 7. Additional Read Replicas

**Status:** Supported

The module supports one or more additional PostgreSQL read replicas through:

```hcl
additional_read_replicas = {
  replica_01 = {
    name                = "<replica-name>"
    resource_group_name = "<resource-group>"
    location            = "USGov Virginia"
    zone                = "1"
  }
}
```

Current tested configuration includes two same-region read replicas.

Additional replicas can also be configured with:

- Private Endpoints
- Private DNS integration
- CMK / UAMI
- Diagnostic Settings
- Tags

Read replicas remain read-only while replication is active.

---

## 8. Active / Passive Cross-Region DR

**Status:** Supported

Use:

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

Characteristics:

- Asynchronous replication
- DR replica is read-only
- Azure does not automatically promote the DR replica
- Promotion is an operational action
- Potential data loss during forced promotion is approximately equal to outstanding replication lag
- HA can be enabled on the newly promoted server after promotion if supported

---

## 9. Independent Primary and Secondary Servers

**Status:** Supported

Deploy two standalone writable PostgreSQL Flexible Servers:

```hcl
create_primary_server   = true
create_dr_replica       = false
create_secondary_server = true
```

Result:

```text
Primary PostgreSQL        Secondary PostgreSQL
     Writable                  Writable
```

The two servers are independent.

They do **not** form a native replicated Active/Active pair.

---

## 10. Active / Active

**Status:** Not supported as a native multi-region PostgreSQL Flexible Server topology.

Azure Database for PostgreSQL Flexible Server does not provide a native multi-region multi-writer Active/Active capability through the read-replica architecture used by this module.

Two standalone PostgreSQL servers may both be writable, but they are independent servers and are not automatically synchronized.

The module intentionally does not describe this as Active/Active.

---

## 11. Planned Failover

**Status:** Supported operationally

Planned failover is performed with:

```powershell
.\scripts\dr-failover.ps1 `
  -SubscriptionId "<subscription-id>" `
  -DrResourceGroup "<dr-resource-group>" `
  -DrServerName "<dr-server>" `
  -Mode Planned `
  -PromotionMode SwitchOver `
  -PostPromotionHAMode SameZone
```

Expected behavior:

```text
Before
Virginia = Primary
Texas    = Read Replica

After
Texas    = Primary
Virginia = Read Replica
```

Requirements:

- Both servers should be healthy.
- Replication lag should be within the agreed RPO.
- Writer and Reader Virtual Endpoints should be configured before `SwitchOver`.
- Application writes should be quiesced where operationally possible.
- HA must be enabled after promotion if required and supported.

---

## 12. Forced Failover

**Status:** Supported operationally

Use only when the original primary is unavailable or recovery cannot meet the required RTO.

Example:

```powershell
.\scripts\dr-failover.ps1 `
  -SubscriptionId "<subscription-id>" `
  -DrResourceGroup "<dr-resource-group>" `
  -DrServerName "<dr-server>" `
  -Mode Forced `
  -PromotionMode SwitchOver `
  -PostPromotionHAMode SameZone
```

A forced failover can result in data loss for transactions that had not yet reached the replica.

Operational approval should be obtained before forced promotion.

---

## 13. Standalone Promotion

**Status:** Supported operationally

A replica can be promoted as a standalone server:

```powershell
.\scripts\dr-promote.ps1 `
  -SubscriptionId "<subscription-id>" `
  -DrResourceGroup "<dr-resource-group>" `
  -DrServerName "<dr-server>" `
  -Mode Forced `
  -PromotionMode Standalone
```

This intentionally breaks the replication relationship.

After promotion:

```text
Virginia Server          Texas Server
Independent              Independent
Writable                 Writable
```

Replication must be rebuilt if Active/Passive DR is required again.

---

## 14. Failback

**Status:** Supported operationally

After the original primary region has recovered and the original primary is again operating as a healthy replica, use:

```powershell
.\scripts\dr-failback.ps1 `
  -SubscriptionId "<subscription-id>" `
  -OriginalPrimaryResourceGroup "<primary-resource-group>" `
  -OriginalPrimaryServerName "<primary-server>" `
  -Mode Planned `
  -PostFailbackHAMode SameZone
```

Expected result:

```text
Virginia = Primary
Texas    = Read Replica
```

After failback validate:

- Server roles
- Replication status
- Replication lag
- Virtual Endpoints
- Private Endpoint connectivity
- Private DNS
- CMK
- Entra authentication
- PostgreSQL parameters
- Diagnostics
- Metric alerts
- Backup configuration
- Application traffic

---

## 15. Virtual Endpoints

**Status:** Supported

Writer and Reader Virtual Endpoints should be configured for DR designs using planned `SwitchOver`.

Expected behavior:

```text
Writer Virtual Endpoint
        |
        v
Current Primary
```

and:

```text
Reader Virtual Endpoint
        |
        v
Current Read Replica
```

After a successful planned role swap, the virtual endpoints follow the PostgreSQL roles.

Virtual endpoints reduce the need for application connection-string changes during planned DR operations.

---

## 16. Private Endpoint Networking

**Status:** Supported

The module supports Private Endpoints for:

```text
Primary PostgreSQL
DR PostgreSQL
Additional Read Replicas
Primary Key Vault
DR Key Vault
```

PostgreSQL Azure Government Private DNS:

```text
privatelink.postgres.database.usgovcloudapi.net
```

Key Vault Azure Government Private DNS:

```text
privatelink.vaultcore.usgovcloudapi.net
```

---

## 17. Customer-Managed Keys

**Status:** Supported

The module supports separate regional CMK stacks:

```text
Primary PostgreSQL
  -> Primary UAMI
  -> Primary Key Vault
  -> Primary CMK

DR PostgreSQL
  -> DR UAMI
  -> DR Key Vault
  -> DR CMK
```

The module intentionally avoids cross-region CMK fallback.

Same-region additional read replicas may reuse the regional UAMI/CMK where that matches the intended security design.

---

## 18. Monitoring and Diagnostics

**Status:** Supported

The module supports:

```text
Primary Diagnostic Settings
DR Diagnostic Settings
Additional Read Replica Diagnostic Settings
Log Analytics
Azure Monitor Metric Alerts
Action Groups
Workbooks
```

Current metric-alert targeting supports:

```text
primary
dr
```

The currently implemented Primary baseline includes:

```text
Database availability
High CPU
Critical CPU
High memory
Critical memory
High storage usage
Critical storage usage
```

Additional replica-specific metric alerts require corresponding replica-target resolution in the module.

---

## 19. Backup

**Status:** Supported

The module supports:

```text
Native PostgreSQL backup retention
On-demand PostgreSQL backups
Azure Data Protection / LTR
```

Operational backup creation is also supported through:

```powershell
.\scripts\create-on-demand-backup.ps1
```

---

## 20. Extensions

**Status:** Supported

Terraform manages the Azure PostgreSQL extension allowlist.

Example:

```hcl
extensions = [
  "uuid-ossp",
  "pg_stat_statements"
]
```

Database-level extension installation is performed separately using:

```powershell
.\scripts\install-extensions.ps1
```

This executes `CREATE EXTENSION` in the target PostgreSQL database.

---

## 21. CREATE / USE EXISTING / NOT CONFIGURED

**Status:** Supported

Major optional resources follow the same pattern.

### CREATE

```hcl
create_primary_key_vault = true
```

### USE EXISTING

```hcl
create_primary_key_vault      = false
existing_primary_key_vault_id = "<resource-id>"
```

### NOT CONFIGURED

```hcl
create_primary_key_vault      = false
existing_primary_key_vault_id = null
```

This pattern applies across major networking, security, monitoring, and backup resources where supported by the module.

---

## 22. Terraform Reconciliation After DR

**Status:** Required operational step

Failover and failback change PostgreSQL server roles outside Terraform.

After promotion:

```text
DO NOT immediately run terraform apply
```

First:

1. Review the actual Azure topology.
2. Review Terraform state.
3. Reconcile primary/DR configuration.
4. Run `terraform plan`.
5. Verify no unintended destroy or replacement.
6. Apply only after the plan matches the intended topology.

See:

```text
docs/DR_RUNBOOK.md
```

for the detailed procedure.

---

## 23. Scenario Summary

| Scenario | Supported | Notes |
|---|---|---|
| Primary only | Yes | Standard single-server deployment |
| Secondary only | Yes | Standalone writable secondary |
| Primary SameZone HA | Yes | Validate SKU/zone support |
| Primary ZoneRedundant HA | Conditional | Validate capability before use |
| Secondary SameZone HA | Yes | For standalone writable secondary where supported |
| Secondary ZoneRedundant HA | Conditional | Validate target region/SKU capability |
| Primary zone selection | Yes | Use `primary_zone` |
| Secondary zone selection | Yes | Use `dr_zone` |
| Additional read replicas | Yes | Multiple replicas supported |
| Same-region read replicas | Yes | Current tested implementation |
| Cross-region DR read replica | Yes | Active/Passive, asynchronous |
| Independent writable primary + secondary | Yes | Not replicated Active/Active |
| Native multi-writer Active/Active | No | Not supported |
| Planned SwitchOver | Yes | Operational script |
| Forced SwitchOver | Yes | Possible data loss |
| Standalone promotion | Yes | Breaks replication relationship |
| Failback | Yes | Operational script |
| Writer/Reader Virtual Endpoints | Yes | Recommended for SwitchOver |
| PostgreSQL Private Endpoint | Yes | Primary, DR, replicas |
| Private Key Vault CMK | Yes | Regional isolation supported |
| Replica diagnostics | Yes | Supported |
| Primary/DR metric alerts | Yes | Target types currently supported |
| Additional replica metric alerts | Not yet | Requires replica alert-target resolution |
| Native backups | Yes | Supported |
| On-demand backups | Yes | Terraform and script options |
| Azure Backup / LTR | Yes | Optional |
| Extension allowlisting | Yes | Terraform |
| Extension installation | Yes | Operational script |
| CREATE / USE EXISTING / NOT CONFIGURED | Yes | Enterprise module pattern |

---

## 24. Capability Validation

Before selecting an availability zone or HA mode, run:

```powershell
.\scripts\feature-inventory.ps1 `
  -SubscriptionId "<subscription-id>" `
  -PrimaryRegion "usgovvirginia" `
  -DrRegion "usgovtexas" `
  -SkuName "Standard_D2s_v3"
```

Use the result rather than relying on region-wide assumptions.

For the current tested Virginia environment, the selected SKU exposed only:

```text
Zone 1
```

and the working configuration therefore uses SameZone HA.

---

## 25. Reference

Detailed DR procedures:

```text
docs/DR_RUNBOOK.md
```

Module overview and deployment guidance:

```text
README.md
```
