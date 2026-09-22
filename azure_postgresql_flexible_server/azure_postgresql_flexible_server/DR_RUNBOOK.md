# Azure Government PostgreSQL Flexible Server DR Runbook

## 1. Purpose

This runbook defines the operational process for Disaster Recovery (DR) of Azure Database for PostgreSQL Flexible Server deployed through this Terraform module.

The supported DR architecture is a **multi-region Active/Passive topology** using an Azure Database for PostgreSQL Flexible Server asynchronous read replica.

The module does not implement or represent a multi-region multi-writer Active/Active PostgreSQL topology.

---

## 2. Supported DR Model

### Recommended topology

| Role | Region | Mode |
|---|---|---|
| Primary / Writer | US Gov Virginia | Read/Write |
| DR Read Replica | US Gov Texas | Passive / Read Replica |
| Replication | Virginia → Texas | Asynchronous |
| Writer Virtual Endpoint | Primary role | Application writer endpoint |
| Reader Virtual Endpoint | Replica role | Read-only / DR endpoint |

Replication between the primary and DR replica is asynchronous.

Azure does **not automatically promote the DR replica** if the primary region becomes unavailable. Promotion must be initiated operationally.

---

## 3. Important DR Characteristics

### Asynchronous replication

Because replication is asynchronous, the DR replica can have replication lag.

During a forced failover, transactions that have not reached the DR replica can be lost.

Before a planned failover, replication lag should be checked and allowed to reach an acceptable level.

### Read replica behavior

While the Texas server is a PostgreSQL read replica:

- It is read-only.
- High Availability cannot be independently enabled on the replica.
- PostgreSQL databases and data replicate from the primary.
- Authentication and PostgreSQL configuration behavior should be validated before DR testing.
- The replica becomes writable only after promotion.

### Terraform ownership

Failover and failback change PostgreSQL replication roles directly in Azure.

These changes occur **outside Terraform**.

After any promotion, failover, or failback:

> Do not run `terraform apply` until the Terraform configuration and state have been reviewed and reconciled with the new Azure topology.

---

## 4. DR Prerequisites

Before enabling or testing DR, verify the following:

1. Virginia primary PostgreSQL Flexible Server is healthy.
2. Texas DR read replica exists and is in `Ready` state.
3. Replication is active.
4. Replication lag is within the agreed RPO.
5. PostgreSQL SKU and storage configuration are compatible.
6. Required PostgreSQL parameters are compatible with role switching.
7. Private Endpoint connectivity is available in both regions.
8. Private DNS resolution is working.
9. CMK / Key Vault access is healthy in both regions where applicable.
10. Azure Monitor diagnostics and alerts are enabled.
11. Writer and Reader Virtual Endpoints are configured before using `SwitchOver`.
12. Application connection strings use the virtual endpoint where role-transparent failover is required.

Run:

```powershell
.\scripts\dr-status.ps1 `
  -SubscriptionId "<subscription-id>" `
  -ResourceGroup "<primary-resource-group>" `
  -ServerName "<primary-server-name>" `
  -IncludeMetrics
```

Review:

- Server state
- Replication role
- Replica state
- HA state
- Virtual endpoints
- `is_db_alive`
- Replication lag

---

## 5. Virtual Endpoint Requirement

Virtual endpoints should be configured before using:

```text
PromotionMode = SwitchOver
```

The updated `dr-promote.ps1` script validates this requirement automatically.

For a planned role swap, the DR replica must be associated with the appropriate virtual endpoint configuration.

If virtual endpoints are not configured, the script should stop rather than performing the switchover.

The expected architecture is:

```text
Application
     |
     v
Writer Virtual Endpoint
     |
     v
Virginia Primary
     |
     | Asynchronous Replication
     v
Texas DR Replica
     ^
     |
Reader Virtual Endpoint
```

After a successful switchover:

```text
Application
     |
     v
Writer Virtual Endpoint
     |
     v
Texas Primary
     |
     | Asynchronous Replication
     v
Virginia Replica
```

The application should continue using the writer virtual endpoint rather than directly using a regional server FQDN.

---

## 6. Planned Failover — Virginia to Texas

Use planned failover when both regions are available and the objective is a controlled role reversal.

Examples include:

- DR testing
- Planned regional maintenance
- Controlled migration
- Business continuity testing

### Step 1 — Check DR status

```powershell
.\scripts\dr-status.ps1 `
  -SubscriptionId "<subscription-id>" `
  -ResourceGroup "<virginia-resource-group>" `
  -ServerName "<virginia-primary-server>" `
  -IncludeMetrics
```

Confirm:

```text
Primary          = Ready
DR Replica       = Ready
Replication      = Healthy
Replication Lag  = Acceptable
```

### Step 2 — Quiesce application writes

Where operationally possible:

1. Stop or drain application write traffic.
2. Allow outstanding transactions to complete.
3. Confirm replication lag is acceptable.
4. Confirm the DR replica is synchronized to the required RPO.

This minimizes data-loss risk during the role transition.

### Step 3 — Perform planned switchover

Run:

```powershell
.\scripts\dr-failover.ps1 `
  -SubscriptionId "<subscription-id>" `
  -DrResourceGroup "<texas-resource-group>" `
  -DrServerName "<texas-dr-server>" `
  -Mode Planned `
  -PromotionMode SwitchOver `
  -PostPromotionHAMode SameZone
```

The script should:

1. Validate the DR server.
2. Verify it is in `Ready` state.
3. Validate its replication relationship.
4. Validate virtual endpoint prerequisites.
5. Promote the Texas replica using a planned switchover.
6. Allow the former Virginia primary to become a replica.
7. Optionally enable HA on the newly promoted Texas primary.
8. Display the resulting HA state.
9. Warn that Terraform topology must be reconciled.

### Step 4 — Validate Texas primary

Run:

```powershell
.\scripts\dr-status.ps1 `
  -SubscriptionId "<subscription-id>" `
  -ResourceGroup "<texas-resource-group>" `
  -ServerName "<texas-server>" `
  -IncludeMetrics
```

Verify:

- Texas server is the writer/primary.
- Virginia server is the replica.
- Writer Virtual Endpoint resolves to Texas.
- Reader Virtual Endpoint resolves to the replica role.
- Application read/write connectivity works.
- Private DNS resolves correctly.
- Private Endpoint connectivity works.
- CMK remains valid.
- Entra authentication works.
- PostgreSQL parameters are correct.
- Diagnostics are working.
- Alerts are healthy.

---

## 7. Forced Regional Failover — Virginia to Texas

Forced failover should only be used when:

- Virginia is unavailable.
- The primary cannot be recovered within the required RTO.
- The business accepts potential data loss equal to outstanding replication lag.

Before proceeding, obtain the required operational approval.

Where the replication topology and virtual endpoints still support role switching:

```powershell
.\scripts\dr-failover.ps1 `
  -SubscriptionId "<subscription-id>" `
  -DrResourceGroup "<texas-resource-group>" `
  -DrServerName "<texas-dr-server>" `
  -Mode Forced `
  -PromotionMode SwitchOver `
  -PostPromotionHAMode SameZone
```

The script should display a warning that transactions not yet replicated to Texas can be lost.

---

## 8. Standalone Promotion

`Standalone` promotion is operationally different from `SwitchOver`.

Example:

```powershell
.\scripts\dr-promote.ps1 `
  -SubscriptionId "<subscription-id>" `
  -DrResourceGroup "<texas-resource-group>" `
  -DrServerName "<texas-dr-server>" `
  -Mode Forced `
  -PromotionMode Standalone
```

Use `Standalone` only when intentionally breaking the replica relationship.

After standalone promotion:

```text
Virginia Server          Texas Server
      |                       |
      |                       |
Independent Server       Independent Server
```

The servers are no longer a managed primary/read-replica pair.

Replication must be rebuilt before normal DR/failback operations can resume.

Because of this, `SwitchOver` is preferred for normal planned DR operations.

---

## 9. High Availability After Promotion

High Availability cannot be independently configured while a PostgreSQL server is functioning as a read replica.

After promotion, HA can be enabled on the newly promoted primary.

The DR scripts expose:

```text
-PostPromotionHAMode None
-PostPromotionHAMode SameZone
-PostPromotionHAMode ZoneRedundant
```

or during failback:

```text
-PostFailbackHAMode None
-PostFailbackHAMode SameZone
-PostFailbackHAMode ZoneRedundant
```

The scripts internally use the current Azure CLI zonal-resiliency configuration.

For the current Azure Government design, use:

```powershell
-PostPromotionHAMode SameZone
```

unless the target subscription, region, SKU, and availability-zone capability have been explicitly validated for ZoneRedundant HA.

Do not assume ZoneRedundant support.

Use `feature-inventory.ps1` or the PostgreSQL capabilities check before changing the HA mode.

---

## 10. Failback — Texas to Virginia

Failback should normally occur only after:

- Virginia has recovered.
- Virginia is again operating as a healthy replica of the Texas primary.
- Replication is healthy.
- Replication lag is acceptable.
- Virtual endpoints are healthy.

### Step 1 — Validate Virginia replica

```powershell
.\scripts\dr-status.ps1 `
  -SubscriptionId "<subscription-id>" `
  -ResourceGroup "<virginia-resource-group>" `
  -ServerName "<virginia-server>" `
  -IncludeMetrics
```

Confirm Virginia is currently functioning as the read replica.

### Step 2 — Perform planned failback

Run:

```powershell
.\scripts\dr-failback.ps1 `
  -SubscriptionId "<subscription-id>" `
  -OriginalPrimaryResourceGroup "<virginia-resource-group>" `
  -OriginalPrimaryServerName "<virginia-server>" `
  -Mode Planned `
  -PostFailbackHAMode SameZone
```

The script should:

1. Validate the Virginia server.
2. Confirm the current replication relationship.
3. Reuse `dr-promote.ps1`.
4. Validate virtual endpoints.
5. Perform a planned `SwitchOver`.
6. Restore Virginia as primary.
7. Make Texas the read replica.
8. Optionally re-enable HA on Virginia.
9. Display the resulting state.
10. Warn that Terraform must be reconciled.

---

## 11. Post-Failback Validation

After failback, validate:

### PostgreSQL

- Virginia is Primary / Writer.
- Texas is Read Replica.
- Both servers report `Ready`.
- Replication is healthy.
- Replication lag is acceptable.

### Networking

- Writer Virtual Endpoint points to Virginia.
- Reader Virtual Endpoint points to Texas.
- PostgreSQL Private Endpoint is healthy.
- Key Vault Private Endpoint is healthy.
- Private DNS resolution is correct.

### Security

- CMK encryption status is valid.
- PostgreSQL UAMI has access to the CMK.
- Entra ID authentication works.
- PostgreSQL administrators are correct.
- Defender settings are correct.

### Database

- Required databases exist.
- Required PostgreSQL extensions are available.
- PostgreSQL parameters are correct.
- PgBouncer settings are correct if enabled.

### Monitoring

- Diagnostic Settings are enabled.
- Log Analytics ingestion is working.
- PostgreSQL metric alerts are enabled.
- Action Groups are enabled.
- `is_db_alive` reports healthy.
- CPU, memory, storage, IOPS, and connection metrics are available.

### Backup

- Native PostgreSQL backup configuration is correct.
- Backup retention is correct.
- Azure Backup/LTR is healthy if configured.
- Restore capability is validated according to the recovery test schedule.

### Application

- Application writer traffic reaches Virginia.
- Read-only traffic reaches the appropriate endpoint where applicable.
- Authentication succeeds.
- Application transactions complete normally.

---

## 12. Terraform Reconciliation After DR

Failover and failback operations modify Azure PostgreSQL roles outside Terraform.

Therefore, after every DR operation:

```text
STOP
 |
 v
Do not immediately run terraform apply
 |
 v
Review actual Azure topology
 |
 v
Update Terraform configuration if required
 |
 v
Review Terraform state
 |
 v
terraform plan
 |
 v
Verify no unintended destroy/replacement
 |
 v
terraform apply
```

At minimum review:

```hcl
create_dr_replica
create_secondary_server
primary_server_name
dr_server_name
virtual_endpoints
primary_high_availability
dr_high_availability
primary_customer_managed_key
dr_customer_managed_key
```

Also review any resource whose logical primary/DR role changed.

Never blindly run `terraform apply` immediately after an operational failover.

---

## 13. DR Status Script

Use:

```powershell
.\scripts\dr-status.ps1 `
  -SubscriptionId "<subscription-id>" `
  -ResourceGroup "<resource-group>" `
  -ServerName "<server-name>"
```

For additional metrics:

```powershell
.\scripts\dr-status.ps1 `
  -SubscriptionId "<subscription-id>" `
  -ResourceGroup "<resource-group>" `
  -ServerName "<server-name>" `
  -IncludeMetrics
```

The script reports:

- Server state
- PostgreSQL version
- Availability zone
- Replication role
- Replica capacity
- Source server
- FQDN
- HA mode
- HA state
- Standby zone
- Read replicas
- Virtual endpoints

When `-IncludeMetrics` is supplied, it also retrieves:

- `is_db_alive`
- `physical_replication_delay_in_seconds` for a replica
- `physical_replication_delay_in_bytes` for a primary

---

## 14. RPO / RTO Considerations

### RPO

Because read-replica replication is asynchronous:

```text
RPO ≈ Outstanding replication lag at the time of failure
```

A planned switchover should normally have a near-zero or operationally acceptable replication lag before promotion.

A forced failover can result in data loss.

### RTO

RTO includes:

```text
Failure detection
      +
Operational decision / approval
      +
Replica promotion
      +
HA activation where required
      +
Virtual endpoint / routing convergence
      +
Application validation
```

RTO should be measured during scheduled DR exercises rather than assumed from infrastructure deployment time.

---

## 15. Active/Active

Azure Database for PostgreSQL Flexible Server does not provide a native multi-region multi-writer Active/Active capability through the read-replica architecture used by this module.

Two standalone PostgreSQL Flexible Servers can both be writable, but they are independent servers and are not a native Active/Active replicated pair.

Therefore this module does not describe or automate such a design as Active/Active.

The supported model is:

```text
US Gov Virginia
Primary / Writer
       |
       | Asynchronous replication
       v
US Gov Texas
Passive Read Replica
```

with controlled promotion for DR.

---

## 16. Recommended DR Test Sequence

For a scheduled DR exercise:

1. Confirm primary and DR health.
2. Check replication lag.
3. Verify virtual endpoints.
4. Verify Private Endpoint/DNS connectivity.
5. Verify CMK health.
6. Quiesce application writes where possible.
7. Run planned failover to Texas.
8. Validate Texas as primary.
9. Validate application functionality.
10. Validate monitoring and alerts.
11. Run planned failback to Virginia.
12. Validate Virginia as primary.
13. Validate Texas as replica.
14. Reconcile Terraform.
15. Run `terraform plan`.
16. Confirm no unintended replacement or destruction.
17. Record actual RPO and RTO.
18. Document test results and exceptions.

---

## 17. Operational Safety

- Do not perform a forced failover or standalone promotion without confirming the operational impact.
- Do not run Terraform immediately after a DR role change until configuration and state have been reconciled.
- Always validate the actual Azure PostgreSQL topology before and after a DR operation.
