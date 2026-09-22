# =============================================================================
# AZURE GOVERNMENT POSTGRESQL FLEXIBLE SERVER - VIRGINIA.TFVARS
# =============================================================================
# PURPOSE
#   Virginia deployment configuration based on the complete enterprise module.
#   Every variable declared in variables.tf remains represented so this file
#   can serve as the Virginia deployment baseline.
#
# CURRENT ACTIVE BASELINE
#   Primary region : USGov Virginia
#   DR region      : USGov Texas (variables retained, ALL DR resources disabled)
#   Primary server: CREATE NEW PostgreSQL Flexible Server
#   Network       : USE EXISTING Virginia VNet / PE subnet
#   PostgreSQL PE : CREATE NEW
#   PostgreSQL DNS: CREATE NEW + VNet link
#   Authentication: Password + Microsoft Entra ID
#   Primary UAMI  : CREATE NEW
#   HA            : SameZone, Zone 1
#   Primary CMK   : ENABLED with independent Virginia Key Vault/key/PE/DNS/RBAC
#   DR CMK stack  : Fully represented below, disabled for this Virginia deployment
#
# VIRGINIA DEPLOYMENT GUARD
#   create_dr_resource_group                 = false
#   create_dr_networking                     = false
#   create_dr_replica                        = false
#   create_secondary_server                  = false
#   create_dr_private_endpoint               = false
#   create_dr_user_assigned_identity         = false
#   create_dr_key_vault                      = false
#   create_dr_key_vault_private_dns_zone     = false
#   create_dr_key_vault_private_dns_vnet_link = false
#   create_dr_key_vault_private_endpoint     = false
#   create_dr_key_vault_key                  = false
#   create_dr_cmk_role_assignment            = false
#   dr_customer_managed_key                  = null
#
# CREATE / USE EXISTING / NOT CONFIGURED
#   create_* = true  + existing_* = null  -> CREATE NEW
#   create_* = false + existing_* supplied -> USE EXISTING
#   create_* = false + existing_* = null   -> NOT CONFIGURED
#
# PASSWORD
#   Do NOT store administrator_password here.
#   PowerShell:
#     $env:TF_VAR_administrator_password = "<password>"
#
# IMPORTANT
#   This is a MASTER file. Enable optional features only after supplying all
#   required dependent inputs for that feature.
# =============================================================================

# =============================================================================
# 0. AZURE GOVERNMENT / SUBSCRIPTION
# =============================================================================
# Azure Government subscription ID used by the AzureRM provider.
subscription_id = "ff3c52c4-f151-4b82-9608-0acc254b0e9b"

# Microsoft Entra tenant ID. Required when Entra authentication or Entra administrators are configured.
tenant_id = "9b1fbe04-6d14-4f30-89d7-150c9fb3252c"

# Primary Azure Government region.
primary_location = "USGov Virginia"

# DR Azure Government region.
dr_location = "USGov Texas"

# Primary deployment shape: server for a standard PostgreSQL Flexible Server, or elastic_cluster for the Flexible Server Elastic Cluster capability. This does not create anything by itself.
deployment_type = "server"

# =============================================================================
# 1. RESOURCE GROUPS - CREATE NEW / USE EXISTING
# =============================================================================
# CREATE the primary resource group. false + name supplied = USE EXISTING; otherwise the optional resource group is not managed.
create_primary_resource_group = false

# Primary resource group name. Used for either a new or existing RG.
primary_resource_group_name = "Omer"

# CREATE the DR resource group. false + name supplied = USE EXISTING; otherwise the optional resource group is not managed.
create_dr_resource_group = false

# DR resource group name. Used for either a new or existing RG.
dr_resource_group_name = null

# =============================================================================
# 2. PRIMARY / DR SERVER TOPOLOGY
# =============================================================================
# CREATE a primary Flexible Server. Set false and provide existing_primary_server_id to USE EXISTING.
create_primary_server = true

# Existing primary Flexible Server ID. Leave null when no existing primary server should be referenced.
existing_primary_server_id = null

# Name for a new primary Flexible Server.
primary_server_name = "otc-dev-ftf-agv-db-gen-psqlfs"

# Create mode for a new primary server: Default, PointInTimeRestore, GeoRestore, ReviveDropped, Replica, or Update.
primary_create_mode = "Default"

# Source server ID for PointInTimeRestore, GeoRestore, Replica, or other source-based creation modes.
primary_source_server_id = null

# RFC3339 UTC restore timestamp for PointInTimeRestore or GeoRestore.
primary_point_in_time_restore_time_in_utc = null

# CREATE the secondary server as a read replica of the primary for Active/Passive DR. Set false when not using replica mode.
create_dr_replica = false

# CREATE a standalone secondary Flexible Server. Use this for a secondary-region-only deployment. Mutually exclusive with create_dr_replica.
create_secondary_server = false

# Existing secondary/DR Flexible Server ID. Use this to reference an existing secondary server instead of creating one.
existing_dr_server_id = null

# Name for a new secondary server, whether standalone or read replica.
dr_server_name = null

# =============================================================================
# 3. COMPUTE / STORAGE / NATIVE BACKUP / HA / MAINTENANCE
# =============================================================================
# PostgreSQL major version for a newly created Default primary.
postgresql_version = "16"

# Primary SKU. Required for create_mode=Default. Null otherwise means provider/service default where valid.
sku_name = "GP_Standard_D2s_v3"

# Optional DR replica SKU override. Null lets Azure/provider inherit or determine the replica SKU.
dr_sku_name = null

# Primary storage size in MiB. Null means do not explicitly set.
storage_mb = 131072

# Optional DR replica storage size in MiB.
dr_storage_mb = null

# Primary storage tier such as P10/P20. Null means do not explicitly set.
storage_tier = null

# Optional DR replica storage tier.
dr_storage_tier = null

# Primary storage autogrow. Null = do not explicitly configure.
auto_grow_enabled = true

# DR storage autogrow. Null = do not explicitly configure.
dr_auto_grow_enabled = null

# Native backup retention for a new primary. Null = provider/service default.
backup_retention_days = 7

# Enable geo-redundant native backup on the primary where supported. Null = do not explicitly configure.
geo_redundant_backup_enabled = null

# Native backup retention for a standalone secondary server. Null = provider/service default. Not applicable to a read replica.
dr_backup_retention_days = null

# Enable geo-redundant native backup on a standalone secondary where supported. US Gov Texas currently does not support geo-redundant backup.
dr_geo_redundant_backup_enabled = null

# Optional primary availability zone.
primary_zone = "1"

# Optional DR availability zone.
dr_zone = null

# Optional primary HA block. Null = HA not configured by this module.
primary_high_availability = {
  mode                      = "SameZone"
  standby_availability_zone = "1"
}

# Optional HA block for a standalone secondary server. Not supported on a read replica. US Gov Texas currently supports SameZone HA but not ZoneRedundant HA.
dr_high_availability = null

# Optional custom maintenance window for a standalone secondary server.
dr_maintenance_window = null

# Optional custom maintenance window. Null = not configured by this module.
maintenance_window = null

# Optional PostgreSQL Flexible Server cluster block. Null = disabled. Validate Azure Government/SKU support before enabling.
elastic_cluster = null

# =============================================================================
# 4. AUTHENTICATION / IDENTITIES / POSTGRESQL CMK BINDING
# =============================================================================
# Authentication configuration for a new Default primary. Null = no auth block.
authentication = {
  password_auth_enabled         = true
  active_directory_auth_enabled = true
  tenant_id                     = "9b1fbe04-6d14-4f30-89d7-150c9fb3252c"
}

# Administrator login for password-authenticated Default creation.
administrator_login = "pgadminuser"

# Sensitive administrator password. Provide through TF_VAR_administrator_password or a pipeline secret; do not store it in sample.tfvars.
administrator_password = "Dummy@2026"
# Use TF_VAR_administrator_password instead.

# CREATE a primary UAMI. false + existing_primary_user_assigned_identity_id supplied = USE EXISTING; otherwise the resource is not managed.
create_primary_user_assigned_identity = true

# Name of the primary UAMI when created.
primary_user_assigned_identity_name = "pg-test-uami-01"

# Existing primary UAMI resource ID.
existing_primary_user_assigned_identity_id = null

# Enable system-assigned identity on a newly created primary.
primary_system_assigned_identity_enabled = true

# CREATE a DR UAMI. false + existing_dr_user_assigned_identity_id supplied = USE EXISTING; otherwise the resource is not managed.
create_dr_user_assigned_identity = false

# Name of the DR UAMI when created.
dr_user_assigned_identity_name = null

# Existing DR UAMI resource ID.
existing_dr_user_assigned_identity_id = null

# Enable system-assigned identity on a newly created DR server/replica where supported.
dr_system_assigned_identity_enabled = false

# Optional primary CMK configuration. Null = Microsoft-managed encryption. key_vault_key_id may be omitted to use only the module-created/supplied PRIMARY regional Key Vault key.
primary_customer_managed_key = {
  key_vault_key_id = "https://otc-dev-ftf-agv-pg-kv.vault.usgovcloudapi.net/keys/otc-dev-ftf-agv-db-gen-psqlfs-cmk-kv"

  primary_user_assigned_identity_id = "/subscriptions/ff3c52c4-f151-4b82-9608-0acc254b0e9b/resourceGroups/Omer/providers/Microsoft.ManagedIdentity/userAssignedIdentities/pg-test-uami-01"
}

# Optional DR CMK configuration. Null = Microsoft-managed encryption. key_vault_key_id may be omitted to use only the module-created/supplied DR regional Key Vault key.
dr_customer_managed_key = null

# Microsoft Entra administrators to manage on the effective primary. Empty map = not configured.
entra_administrators = {
  omer_user = {
    object_id      = "adb0938d-0272-4046-901b-fd182f0f15cf"
    principal_name = "Omer.Farooq@fiservbfs.us"
    principal_type = "User"
  }
  dbdeveloper_group = {
    object_id      = "42a7ba3b-40d5-4a89-92ef-0bce625fc172"
    principal_name = "otc-plat-azg-dbdeveloper-egrp"
    principal_type = "Group"
  }
}

# Apply the same entra_administrators map to the effective DR server.
manage_entra_administrators_on_dr = false

# =============================================================================
# 5. NETWORKING
# =============================================================================
# Primary networking mode: private_endpoint, vnet_integration, public, or null.
networking_mode = "private_endpoint"

# DR networking mode: private_endpoint, vnet_integration, public, or null.
dr_networking_mode = "private_endpoint"

# CREATE the primary VNet and the subnet required by networking_mode. false + IDs supplied = USE EXISTING; otherwise the resource is not managed.
create_primary_networking = false

# CREATE the DR VNet and the subnet required by dr_networking_mode. false + IDs supplied = USE EXISTING; otherwise the resource is not managed.
create_dr_networking = false

# Primary VNet name when create_primary_networking=true.
primary_vnet_name = null

# Primary VNet address space when created.
primary_vnet_address_space = []

# Existing primary VNet ID when networking is not created by this module.
primary_vnet_id = "/subscriptions/ff3c52c4-f151-4b82-9608-0acc254b0e9b/resourceGroups/ta-plat-azgv-rg-sandbox-01/providers/Microsoft.Network/virtualNetworks/ta-plat-azgv-vnet-sandbox-01"

# Primary PE subnet name when networking_mode=private_endpoint and networking is created.
primary_private_endpoint_subnet_name = null

# Primary PE subnet prefixes when created.
primary_private_endpoint_subnet_prefixes = []

# Existing primary PE subnet ID.
primary_private_endpoint_subnet_id = "/subscriptions/ff3c52c4-f151-4b82-9608-0acc254b0e9b/resourceGroups/ta-plat-azgv-rg-sandbox-01/providers/Microsoft.Network/virtualNetworks/ta-plat-azgv-vnet-sandbox-01/subnets/platformsubnet"

# Primary delegated subnet name when networking_mode=vnet_integration and networking is created.
primary_delegated_subnet_name = null

# Primary delegated subnet prefixes when created.
primary_delegated_subnet_prefixes = []

# Existing primary delegated subnet ID for VNet integration.
primary_delegated_subnet_id = null

# DR VNet name when create_dr_networking=true.
dr_vnet_name = null

# DR VNet address space when created.
dr_vnet_address_space = []

# Existing DR VNet ID.
dr_vnet_id = null

# DR PE subnet name when dr_networking_mode=private_endpoint and networking is created.
dr_private_endpoint_subnet_name = null

# DR PE subnet prefixes when created.
dr_private_endpoint_subnet_prefixes = []

# Existing DR PE subnet ID.
dr_private_endpoint_subnet_id = null

# DR delegated subnet name when dr_networking_mode=vnet_integration and networking is created.
dr_delegated_subnet_name = null

# DR delegated subnet prefixes when created.
dr_delegated_subnet_prefixes = []

# Existing DR delegated subnet ID for VNet integration.
dr_delegated_subnet_id = null

# =============================================================================
# 6. POSTGRESQL PRIVATE DNS
# =============================================================================
# CREATE the private DNS zone. false + existing_private_dns_zone_id supplied = USE EXISTING; otherwise the resource is not managed.
create_private_dns_zone = true

# Private DNS zone name when created. For Azure Gov Private Link the standard zone is privatelink.postgres.database.usgovcloudapi.net.
private_dns_zone_name = "privatelink.postgres.database.usgovcloudapi.net"

# Resource group for a newly created Private DNS zone.
private_dns_zone_resource_group_name = "Omer"

# Existing Private DNS zone ID.
existing_private_dns_zone_id = null

# DNS VNet links to create. Use vnet_id='primary' or 'dr' to reference module/effective VNets, or supply a full VNet ID. Empty map = not configured.
private_dns_vnet_links = {
  primary = {
    name    = "otc-dev-ftf-agv-dns-gen-pe-01"
    vnet_id = "primary"
  }
}

# =============================================================================
# 7. VNET-INTEGRATION PRIVATE DNS
# =============================================================================
# CREATE the Private DNS zone used by delegated-subnet VNet integration. This is separate from the Private Link zone.
create_vnet_integration_private_dns_zone = false

# Private DNS zone name for VNet integration. It must end in .postgres.database.azure.com.
vnet_integration_private_dns_zone_name = null

# Resource group for a newly created VNet-integration Private DNS zone.
vnet_integration_private_dns_zone_resource_group_name = null

# Existing Private DNS zone ID for delegated-subnet VNet integration.
existing_vnet_integration_private_dns_zone_id = null

# VNet links for the VNet-integration DNS zone. Use vnet_id='primary' or 'dr', or provide a full VNet ID.
vnet_integration_dns_vnet_links = {}

# =============================================================================
# 8. POSTGRESQL PRIVATE ENDPOINTS
# =============================================================================
# CREATE primary PostgreSQL Private Endpoint. false + existing_primary_private_endpoint_id supplied = USE EXISTING; otherwise the resource is not managed.
create_primary_private_endpoint = true

# Existing primary PostgreSQL Private Endpoint ID.
existing_primary_private_endpoint_id = null

# Primary Private Endpoint name when created.
primary_private_endpoint_name = "otc-dev-ftf-agv-db-gen-pe-01"

# CREATE DR PostgreSQL Private Endpoint. false + existing_dr_private_endpoint_id supplied = USE EXISTING; otherwise the resource is not managed.
create_dr_private_endpoint = false

# Existing DR PostgreSQL Private Endpoint ID.
existing_dr_private_endpoint_id = null

# DR Private Endpoint name when created.
dr_private_endpoint_name = null

# Attach the effective private DNS zone to Private Endpoint DNS zone groups. false = create PE without DNS zone group.
private_endpoint_attach_dns_zone = true

# =============================================================================
# 9. DATABASES / PARAMETERS / EXTENSIONS / PGBOUNCER / FIREWALL
# =============================================================================
# Databases to create on the effective primary. Empty map = not configured.
database_definitions = {
  appdb = {
    charset   = "UTF8"
    collation = "en_US.utf8"
  }
}

# Databases to create on a standalone secondary server. Keep empty for Active/Passive read-replica mode because databases replicate from the primary.
secondary_database_definitions = {}

# Flexible Server configuration parameters on the effective primary. Empty map = not configured.
server_parameters = {}

# Primary-only server parameter overrides. Empty map = not configured.
primary_server_parameter_overrides = {}

# Apply the primary effective parameter set to the effective DR server.
apply_server_parameters_to_dr = false

# DR-only server parameter overrides. Empty map = not configured.
dr_server_parameter_overrides = {}

# Extension names to allowlist through azure.extensions on the primary. Empty set = not configured.
extensions = []

# Manage pgbouncer.enabled. Null = not configured; true/false explicitly sets the parameter.
pgbouncer_enabled = null

# Firewall rules. target must be primary or dr. Empty map = not configured. Intended for public networking only.
firewall_rules = {}

# =============================================================================
# 10. READ REPLICAS / VIRTUAL ENDPOINTS / ON-DEMAND BACKUPS
# =============================================================================
# Additional direct read replicas. Empty map = not configured. Azure supports up to 5 direct read replicas per source; create_dr_replica also consumes one direct-replica slot. Existing additional replicas are intentionally left unmanaged unless imported.
additional_read_replicas = {
  virginia_rr_01 = {
    name                = "otc-dev-ftf-agv-db-gen-psqlfs-rr-01"
    resource_group_name = "Omer"
    location            = "USGov Virginia"

    networking_mode = "private_endpoint"

    sku_name          = "GP_Standard_D2s_v3"
    storage_mb        = 131072
    auto_grow_enabled = true
    zone              = "1"

    # System Assigned + User Assigned Identity
    system_assigned_identity_enabled = true
    user_assigned_identity_id        = "/subscriptions/ff3c52c4-f151-4b82-9608-0acc254b0e9b/resourceGroups/Omer/providers/Microsoft.ManagedIdentity/userAssignedIdentities/pg-test-uami-01"

    key_vault_key_id = "https://otc-dev-ftf-agv-pg-kv.vault.usgovcloudapi.net/keys/otc-dev-ftf-agv-db-gen-psqlfs-cmk-kv"

    # CREATE Private Endpoint
    create_private_endpoint = true

    private_endpoint_name = "otc-dev-ftf-agv-db-gen-psqlfs-rr01-pe-01"

    private_endpoint_subnet_id = "/subscriptions/ff3c52c4-f151-4b82-9608-0acc254b0e9b/resourceGroups/ta-plat-azgv-rg-sandbox-01/providers/Microsoft.Network/virtualNetworks/ta-plat-azgv-vnet-sandbox-01/subnets/platformsubnet"

    private_endpoint_attach_dns_zone = true
    # Diagnostic Settings -> existing/effective Log Analytics Workspace
    enable_diagnostics = false

    tags = {
      Replica = "01"
      Zone    = "1"
    }
  }

  virginia_rr_02 = {
    name                = "otc-dev-ftf-agv-db-gen-psqlfs-rr-02"
    resource_group_name = "Omer"
    location            = "USGov Virginia"

    networking_mode = "private_endpoint"

    sku_name          = "GP_Standard_D2s_v3"
    storage_mb        = 131072
    auto_grow_enabled = true
    zone              = "1"

    # System Assigned + User Assigned Identity
    system_assigned_identity_enabled = true
    user_assigned_identity_id        = "/subscriptions/ff3c52c4-f151-4b82-9608-0acc254b0e9b/resourceGroups/Omer/providers/Microsoft.ManagedIdentity/userAssignedIdentities/pg-test-uami-01"

    key_vault_key_id = "https://otc-dev-ftf-agv-pg-kv.vault.usgovcloudapi.net/keys/otc-dev-ftf-agv-db-gen-psqlfs-cmk-kv"

    # CREATE Private Endpoint
    create_private_endpoint = true

    private_endpoint_name = "otc-dev-ftf-agv-db-gen-psqlfs-rr02-pe-01"

    private_endpoint_subnet_id = "/subscriptions/ff3c52c4-f151-4b82-9608-0acc254b0e9b/resourceGroups/ta-plat-azgv-rg-sandbox-01/providers/Microsoft.Network/virtualNetworks/ta-plat-azgv-vnet-sandbox-01/subnets/platformsubnet"

    private_endpoint_attach_dns_zone = true
    # Diagnostic Settings -> existing/effective Log Analytics Workspace
    enable_diagnostics = false

    tags = {
      Replica = "02"
      Zone    = "1"
    }
  }
}

# Virtual endpoints to create between the effective primary and DR servers. type is ReadWrite or ReadOnly. Empty map = not configured.
virtual_endpoints = {}

# Optional IDs of existing virtual endpoints to surface in outputs without recreating them. Empty map = not configured.
existing_virtual_endpoint_ids = {}

# On-demand backups to create. target must be primary or dr. Empty map = not configured.
on_demand_backups = {}

# =============================================================================
# 11. LOG ANALYTICS / DIAGNOSTICS / METRIC ALERTS
# =============================================================================
# CREATE a Log Analytics workspace. false + existing_log_analytics_workspace_id supplied = USE EXISTING; otherwise the resource is not managed.
create_log_analytics_workspace = true

# Existing Log Analytics workspace ID.
existing_log_analytics_workspace_id = null

# Workspace name when created.
log_analytics_workspace_name = "otc-dev-ftf-agv-log-gen-psqlfs-01"

# Workspace resource group when created.
log_analytics_resource_group_name = "Omer"

# Workspace location when created.
log_analytics_location = "USGov Virginia"

# Workspace retention days when created.
log_analytics_retention_days = 30

# Create diagnostic settings for the effective primary server.
enable_primary_diagnostics = false

# Create diagnostic settings for the effective DR server.
enable_dr_diagnostics = false

# Optional Storage Account destination for diagnostic settings.
diagnostic_storage_account_id = null

# Optional Event Hub name for diagnostic settings.
diagnostic_eventhub_name = null

# Optional Event Hub authorization rule ID for diagnostic settings.
diagnostic_eventhub_authorization_rule_id = null

# Diagnostic log categories. Empty set means discover and enable all supported log categories when diagnostics are enabled.
diagnostic_log_categories = []

# Diagnostic metric categories. Empty set means discover and enable all supported metric categories when diagnostics are enabled.
diagnostic_metric_categories = []

# Metric alerts for primary/dr servers. Empty map = not configured.
metric_alerts = {
  # ===========================================================================
  # 1. PRIMARY DATABASE UNAVAILABLE
  # ===========================================================================
  primary_database_unavailable = {
    target                   = "primary"
    metric_name              = "is_db_alive"
    aggregation              = "Maximum"
    operator                 = "LessThan"
    threshold                = 1
    severity                 = 0
    frequency                = "PT1M"
    window_size              = "PT5M"
    description              = "Detect primary PostgreSQL database outage."
    use_default_action_group = true
  }

  # ===========================================================================
  # 2. HIGH CPU
  # ===========================================================================
  primary_high_cpu = {
    target                   = "primary"
    metric_name              = "cpu_percent"
    aggregation              = "Average"
    operator                 = "GreaterThan"
    threshold                = 80
    severity                 = 2
    frequency                = "PT5M"
    window_size              = "PT15M"
    description              = "Detect sustained CPU pressure above 80 percent."
    use_default_action_group = true
  }

  # ===========================================================================
  # 3. CPU CRITICAL
  # ===========================================================================
  primary_cpu_critical = {
    target                   = "primary"
    metric_name              = "cpu_percent"
    aggregation              = "Average"
    operator                 = "GreaterThan"
    threshold                = 95
    severity                 = 1
    frequency                = "PT5M"
    window_size              = "PT15M"
    description              = "Detect severe CPU saturation above 95 percent."
    use_default_action_group = true
  }

  # ===========================================================================
  # 4. HIGH MEMORY
  # ===========================================================================
  primary_high_memory = {
    target                   = "primary"
    metric_name              = "memory_percent"
    aggregation              = "Average"
    operator                 = "GreaterThan"
    threshold                = 85
    severity                 = 2
    frequency                = "PT5M"
    window_size              = "PT15M"
    description              = "Detect sustained memory pressure above 85 percent."
    use_default_action_group = true
  }

  # ===========================================================================
  # 5. MEMORY CRITICAL
  # ===========================================================================
  primary_memory_critical = {
    target                   = "primary"
    metric_name              = "memory_percent"
    aggregation              = "Average"
    operator                 = "GreaterThan"
    threshold                = 95
    severity                 = 1
    frequency                = "PT5M"
    window_size              = "PT15M"
    description              = "Detect severe memory pressure above 95 percent."
    use_default_action_group = true
  }

  # ===========================================================================
  # 6. HIGH STORAGE USAGE
  # ===========================================================================
  primary_high_storage_usage = {
    target                   = "primary"
    metric_name              = "storage_percent"
    aggregation              = "Average"
    operator                 = "GreaterThan"
    threshold                = 80
    severity                 = 1
    frequency                = "PT5M"
    window_size              = "PT15M"
    description              = "Early warning for PostgreSQL storage exhaustion."
    use_default_action_group = true
  }

  # ===========================================================================
  # 7. STORAGE CRITICAL
  # ===========================================================================
  primary_storage_critical = {
    target                   = "primary"
    metric_name              = "storage_percent"
    aggregation              = "Average"
    operator                 = "GreaterThan"
    threshold                = 90
    severity                 = 0
    frequency                = "PT1M"
    window_size              = "PT5M"
    description              = "Critical PostgreSQL storage capacity threshold exceeded."
    use_default_action_group = true
  }

}

# =============================================================================
# 12. QUERY STORE / AUTONOMOUS TUNING / LOGGING / DEFENDER
# =============================================================================
# Friendly Query Store / Query Performance Insight configuration for the primary. Null = NOT CONFIGURED. Not supported for Elastic Cluster.
query_store = null

# Friendly Autonomous Tuning configuration for the primary. Null = NOT CONFIGURED. enabled=true emits index tuning recommendations; read replicas and Elastic Cluster are not targeted.
autonomous_tuning = null

# Friendly PostgreSQL server logging configuration on the primary. Null = NOT CONFIGURED. Generic server_parameters can still be used for additional settings.
logging = {
  log_connections            = true
  log_disconnections         = true
  log_checkpoints            = true
  log_min_duration_statement = 1000
}

# Manage the subscription Defender plan for OpenSourceRelationalDatabases. null = preserve existing / do not manage; Standard = enable; Free = disable paid plan.
defender_subscription_plan_tier = null

# Resource-level PostgreSQL advanced threat protection state. null = preserve existing / do not manage; Enabled/Disabled = manage explicitly through AzAPI.
primary_defender_threat_protection_state = null

# Resource-level DR PostgreSQL advanced threat protection state. null = preserve existing / do not manage; Enabled/Disabled = manage explicitly through AzAPI.
dr_defender_threat_protection_state = null

# =============================================================================
# 13. AZURE BACKUP / LONG-TERM RETENTION
# =============================================================================
# CREATE an Azure Data Protection Backup Vault for PostgreSQL LTR. false + existing_backup_vault_id = USE EXISTING; otherwise the resource is not managed.
create_backup_vault = false

# Existing Backup Vault resource ID. Null + create_backup_vault=false means no Backup Vault is managed.
existing_backup_vault_id = null

# System-assigned identity principal ID of an existing Backup Vault. Required only when this module manages LTR role assignments for an existing vault.
existing_backup_vault_principal_id = null

# Backup Vault name when created.
backup_vault_name = null

# Backup Vault resource group name when created.
backup_vault_resource_group_name = null

# Backup Vault location when created.
backup_vault_location = null

# Backup Vault redundancy when created.
backup_vault_redundancy = null

# Optional cross-region restore setting for a GeoRedundant Backup Vault. Null = use the provider default and do not explicitly configure this setting.
backup_vault_cross_region_restore_enabled = null

# Optional Backup Vault soft delete state: AlwaysOn, Off, or On. Null = provider default.
backup_vault_soft_delete = null

# Optional Backup Vault soft-delete retention, 14-180 days. Null = provider default.
backup_vault_retention_duration_in_days = null

# CREATE a PostgreSQL Flexible Server LTR backup policy. false + existing_backup_policy_id = USE EXISTING; otherwise the resource is not managed.
create_backup_policy = false

# Existing PostgreSQL Flexible Server backup policy ID.
existing_backup_policy_id = null

# LTR backup policy name when created.
backup_policy_name = null

# Weekly ISO 8601 repeating intervals for PostgreSQL Flexible Server LTR policy. Empty = no policy creation input.
backup_repeating_time_intervals = []

# Optional time zone for LTR backup policy.
backup_policy_time_zone = null

# ISO 8601 duration for the default LTR retention rule, e.g. P4M or P7Y.
backup_policy_default_retention_duration = null

# Optional named LTR retention rules. Empty map = only default rule.
backup_policy_retention_rules = {}

# CREATE Azure Backup protection for the effective primary server. false + existing_ltr_backup_instance_id = USE EXISTING/surface; otherwise the resource is not managed.
create_ltr_backup_instance = false

# Existing PostgreSQL Flexible Server Backup Instance ID.
existing_ltr_backup_instance_id = null

# Backup Instance name when created.
ltr_backup_instance_name = null

# Backup Instance source database location. Null uses primary_location when creating.
ltr_backup_instance_location = null

# Create the documented Reader + PostgreSQL Flexible Server Long Term Retention Backup Role assignments for the Backup Vault identity.
manage_ltr_role_assignments = false

# =============================================================================
# 14. ACTION GROUP / WORKBOOK / ADVISOR
# =============================================================================
# CREATE a default Azure Monitor Action Group.
create_monitor_action_group = true

# No existing Action Group is being reused.
existing_monitor_action_group_id = null

# Action Group name.
monitor_action_group_name = "ag-otc-dev-ftf-agv-postgresql"

# Create Action Group in Omer RG.
monitor_action_group_resource_group_name = "Omer"

# Azure Monitor Action Group short name.
monitor_action_group_short_name = "pg-alerts"

# Action Groups are global resources.
monitor_action_group_location = "global"

# Enable Action Group.
monitor_action_group_enabled = true

# Email receiver.
action_group_email_receivers = {
  dbops = {
    email_address           = "Omer.Farooq@fiserv.com"
    use_common_alert_schema = true
  }
}

# SMS not configured.
action_group_sms_receivers = {}

# Webhook not configured.
action_group_webhook_receivers = {}

# CREATE an Azure Monitor Workbook. false + existing_monitor_workbook_id = USE EXISTING/surface; otherwise the resource is not managed.
create_monitor_workbook = false

# Existing Azure Monitor Workbook ID.
existing_monitor_workbook_id = null

# Workbook resource name as a lowercase UUID/GUID.
monitor_workbook_name = null

# Workbook resource group name.
monitor_workbook_resource_group_name = null

# Workbook location.
monitor_workbook_location = null

# Workbook display name.
monitor_workbook_display_name = null

# Workbook configuration JSON string.
monitor_workbook_data_json = null

# Optional Workbook source resource ID.
monitor_workbook_source_id = null

# Azure Advisor suppressions. Empty map = not configured.
advisor_suppressions = {}

# =============================================================================
# 15. ENTERPRISE CROSS-REGION CMK RBAC
# =============================================================================
# Backward-compatible master switch. When true, create both applicable regional Key Vault Crypto Service Encryption User assignments. Prefer the regional switches for new deployments.
create_cmk_role_assignments = false

# Create Key Vault Crypto Service Encryption User on the effective PRIMARY Key Vault for the effective primary PostgreSQL UAMI.
create_primary_cmk_role_assignment = true

# Create Key Vault Crypto Service Encryption User on the effective DR Key Vault for the effective DR PostgreSQL UAMI.
create_dr_cmk_role_assignment = false

# =============================================================================
# 16. PRIMARY KEY VAULT
# =============================================================================
# CREATE the primary-region Key Vault for PostgreSQL CMK. false + existing_primary_key_vault_id = USE EXISTING; otherwise not managed.
create_primary_key_vault = true

# Existing primary-region Key Vault resource ID.
existing_primary_key_vault_id = null

# Primary-region Key Vault name when created.
primary_key_vault_name = "otc-dev-ftf-agv-pg-kv"

# Primary-region Key Vault resource group. Also used for a module-created primary Key Vault Private Endpoint.
primary_key_vault_resource_group_name = "Omer"

# Primary-region Key Vault location. Typically the same as primary_location.
primary_key_vault_location = "USGov Virginia"

# Primary-region Key Vault SKU.
primary_key_vault_sku_name = "standard"

# Enable RBAC authorization on a module-created primary CMK Key Vault. Enterprise secure default is true.
primary_key_vault_rbac_authorization_enabled = true

# Enable purge protection on a module-created primary CMK Key Vault.
primary_key_vault_purge_protection_enabled = true

# Compatibility guard. main.tf hard-disables public access on a module-created primary CMK Key Vault; keep false.
primary_key_vault_public_network_access_enabled = false

# Primary Key Vault soft-delete retention days, 7-90.
primary_key_vault_soft_delete_retention_days = 90

# Network ACLs for a module-created primary CMK Key Vault.
primary_key_vault_network_acls = {
  bypass                     = "AzureServices"
  default_action             = "Deny"
  ip_rules                   = []
  virtual_network_subnet_ids = []
}

# =============================================================================
# 17. DR KEY VAULT
# =============================================================================
# CREATE the DR-region Key Vault for PostgreSQL CMK. false + existing_dr_key_vault_id = USE EXISTING; otherwise not managed.
create_dr_key_vault = false

# Existing DR-region Key Vault resource ID.
existing_dr_key_vault_id = null

# DR-region Key Vault name when created.
dr_key_vault_name = null

# DR-region Key Vault resource group. Also used for a module-created DR Key Vault Private Endpoint.
dr_key_vault_resource_group_name = null

# DR-region Key Vault location. Typically the same as dr_location.
dr_key_vault_location = null

# DR-region Key Vault SKU.
dr_key_vault_sku_name = "standard"

# Enable RBAC authorization on a module-created DR CMK Key Vault.
dr_key_vault_rbac_authorization_enabled = true

# Enable purge protection on a module-created DR CMK Key Vault.
dr_key_vault_purge_protection_enabled = true

# Compatibility guard. main.tf hard-disables public access on a module-created DR CMK Key Vault; keep false.
dr_key_vault_public_network_access_enabled = false

# DR Key Vault soft-delete retention days, 7-90.
dr_key_vault_soft_delete_retention_days = 90

# Network ACLs for a module-created DR CMK Key Vault.
dr_key_vault_network_acls = {
  bypass                     = "AzureServices"
  default_action             = "Deny"
  ip_rules                   = []
  virtual_network_subnet_ids = []
}

# =============================================================================
# 18. PRIMARY / DR KEY VAULT PRIVATE DNS + VNET LINKS
# =============================================================================
# CREATE the primary Azure Government Key Vault Private DNS zone. false + existing ID = USE EXISTING.
create_primary_key_vault_private_dns_zone = false

# Existing primary Key Vault Private DNS zone ID.
existing_primary_key_vault_private_dns_zone_id = "/subscriptions/08afe5c0-f1ed-49eb-813c-eac5c9f888d6/resourceGroups/ta-plat-prod-azgv-rg-connectivity-01/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.usgovcloudapi.net"

# Primary Key Vault Private DNS zone. Azure Government standard is privatelink.vaultcore.usgovcloudapi.net.
primary_key_vault_private_dns_zone_name = "privatelink.vaultcore.usgovcloudapi.net"

# Resource group for a newly created primary Key Vault Private DNS zone.
primary_key_vault_private_dns_zone_resource_group_name = null

# CREATE the link from the effective primary Key Vault Private DNS zone to the effective primary VNet.
create_primary_key_vault_private_dns_vnet_link = false

# Primary Key Vault Private DNS VNet link name.
primary_key_vault_private_dns_vnet_link_name = null

# CREATE the DR Azure Government Key Vault Private DNS zone. false + existing ID = USE EXISTING.
create_dr_key_vault_private_dns_zone = false

# Existing DR Key Vault Private DNS zone ID.
existing_dr_key_vault_private_dns_zone_id = null

# DR Key Vault Private DNS zone. Azure Government standard is privatelink.vaultcore.usgovcloudapi.net.
dr_key_vault_private_dns_zone_name = "privatelink.vaultcore.usgovcloudapi.net"

# Resource group for a newly created DR Key Vault Private DNS zone.
dr_key_vault_private_dns_zone_resource_group_name = null

# CREATE the link from the effective DR Key Vault Private DNS zone to the effective DR VNet.
create_dr_key_vault_private_dns_vnet_link = false

# DR Key Vault Private DNS VNet link name.
dr_key_vault_private_dns_vnet_link_name = null

# =============================================================================
# 19. PRIMARY / DR KEY VAULT PRIVATE ENDPOINTS
# =============================================================================
# CREATE a Private Endpoint for the effective primary CMK Key Vault. false + existing ID = USE EXISTING.
create_primary_key_vault_private_endpoint = true

# Existing primary Key Vault Private Endpoint ID.
existing_primary_key_vault_private_endpoint_id = null

# Primary Key Vault Private Endpoint name.
primary_key_vault_private_endpoint_name = "otc-dev-ftf-agv-db-gen-psqlfs-kv-pe-01"

# Subnet ID for the primary Key Vault Private Endpoint. Null reuses the effective primary PostgreSQL PE subnet.
primary_key_vault_private_endpoint_subnet_id = "/subscriptions/ff3c52c4-f151-4b82-9608-0acc254b0e9b/resourceGroups/ta-plat-azgv-rg-sandbox-01/providers/Microsoft.Network/virtualNetworks/ta-plat-azgv-vnet-sandbox-01/subnets/platformsubnet"

# CREATE a Private Endpoint for the effective DR CMK Key Vault. false + existing ID = USE EXISTING.
create_dr_key_vault_private_endpoint = false

# Existing DR Key Vault Private Endpoint ID.
existing_dr_key_vault_private_endpoint_id = null

# DR Key Vault Private Endpoint name.
dr_key_vault_private_endpoint_name = null

# Subnet ID for the DR Key Vault Private Endpoint. Null reuses the effective DR PostgreSQL PE subnet.
dr_key_vault_private_endpoint_subnet_id = null

# =============================================================================
# 20. PRIMARY / DR KEY VAULT KEYS
# =============================================================================
# CREATE the primary regional Key Vault CMK key. false + existing ID = USE EXISTING.
create_primary_key_vault_key = false

# Existing primary regional versionless or versioned Key Vault key ID.
existing_primary_key_vault_key_id = "https://otc-dev-ftf-agv-pg-kv.vault.usgovcloudapi.net/keys/otc-dev-ftf-agv-db-gen-psqlfs-cmk-kv"

# Primary regional CMK key name.
primary_key_vault_key_name = "otc-dev-ftf-agv-db-gen-psqlfs-cmk-kv"

# Primary CMK key type: EC, EC-HSM, RSA, or RSA-HSM.
primary_key_vault_key_type = "RSA"

# Primary RSA/RSA-HSM CMK size.
primary_key_vault_key_size = 4096

# Optional EC curve for the primary EC/EC-HSM CMK.
primary_key_vault_key_curve = null

# Primary CMK key operations.
primary_key_vault_key_opts = ["unwrapKey", "wrapKey"]

# CREATE the DR regional Key Vault CMK key. false + existing ID = USE EXISTING.
create_dr_key_vault_key = false

# Existing DR regional versionless or versioned Key Vault key ID.
existing_dr_key_vault_key_id = null

# DR regional CMK key name.
dr_key_vault_key_name = null

# DR CMK key type: EC, EC-HSM, RSA, or RSA-HSM.
dr_key_vault_key_type = "RSA"

# DR RSA/RSA-HSM CMK size.
dr_key_vault_key_size = 4096

# Optional EC curve for the DR EC/EC-HSM CMK.
dr_key_vault_key_curve = null

# DR CMK key operations.
dr_key_vault_key_opts = ["unwrapKey", "wrapKey"]

# =============================================================================
# 21. GOVERNANCE / RBAC / TAGS
# =============================================================================
# Optional management lock on effective primary: CanNotDelete or ReadOnly. Null = NOT CONFIGURED.
primary_server_lock_level = null

# Optional management lock on effective DR: CanNotDelete or ReadOnly. Null = NOT CONFIGURED.
dr_server_lock_level = null

# RBAC assignments. scope can be primary_server, dr_server, private_dns_zone, log_analytics, primary_key_vault, dr_key_vault, backup_vault, action_group, or a full Azure resource ID. Empty map = not configured.
role_assignments = {}

# Tags applied to resources created by this module. Empty map = no tags.
tags = {
  ManagedBy    = "Terraform"
  Environment  = "POC"
  Service      = "PostgreSQL"
  Architecture = "Virginia-Primary-Enterprise-CMK"
  Cloud        = "AzureUSGovernment"
}

# =============================================================================
# MASTER COVERAGE CHECK
# =============================================================================
# This file contains every variable declared by the current updated variables.tf.
# DR/Texas inputs are present even where disabled so the same file can be used
# later for primary-only, secondary-only, or active/passive cross-region tests.
# =============================================================================
