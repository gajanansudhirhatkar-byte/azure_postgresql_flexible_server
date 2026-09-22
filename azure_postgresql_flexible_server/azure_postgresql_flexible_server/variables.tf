variable "subscription_id" {
  description = "Azure Government subscription ID used by the AzureRM provider."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID. Required when Entra authentication or Entra administrators are configured."
  type        = string
  default     = null
}

variable "primary_location" {
  description = "Primary Azure Government region."
  type        = string
  default     = "USGov Virginia"
}

variable "dr_location" {
  description = "DR Azure Government region."
  type        = string
  default     = "USGov Texas"
}

variable "deployment_type" {
  description = "Primary deployment shape: server for a standard PostgreSQL Flexible Server, or elastic_cluster for the Flexible Server Elastic Cluster capability. This does not create anything by itself."
  type        = string
  default     = "server"

  validation {
    condition     = contains(["server", "elastic_cluster"], var.deployment_type)
    error_message = "deployment_type must be server or elastic_cluster."
  }
}

# =============================================================================
# CREATE NEW / USE EXISTING - RESOURCE GROUPS
# =============================================================================
variable "create_primary_resource_group" {
  description = "CREATE the primary resource group. false + name supplied = USE EXISTING; otherwise the optional resource group is not managed."
  type        = bool
  default     = false
}

variable "primary_resource_group_name" {
  description = "Primary resource group name. Used for either a new or existing RG."
  type        = string
  default     = null
}

variable "create_dr_resource_group" {
  description = "CREATE the DR resource group. false + name supplied = USE EXISTING; otherwise the optional resource group is not managed."
  type        = bool
  default     = false
}

variable "dr_resource_group_name" {
  description = "DR resource group name. Used for either a new or existing RG."
  type        = string
  default     = null
}

# =============================================================================
# CREATE NEW / USE EXISTING - PRIMARY / DR SERVERS
# =============================================================================
variable "create_primary_server" {
  description = "CREATE a primary Flexible Server. Set false and provide existing_primary_server_id to USE EXISTING."
  type        = bool
  default     = false
}

variable "existing_primary_server_id" {
  description = "Existing primary Flexible Server ID. Leave null when no existing primary server should be referenced."
  type        = string
  default     = null
}

variable "primary_server_name" {
  description = "Name for a new primary Flexible Server."
  type        = string
  default     = null
}

variable "primary_create_mode" {
  description = "Create mode for a new primary server: Default, PointInTimeRestore, GeoRestore, ReviveDropped, Replica, or Update."
  type        = string
  default     = "Default"

  validation {
    condition     = contains(["Default", "PointInTimeRestore", "GeoRestore", "ReviveDropped", "Replica", "Update"], var.primary_create_mode)
    error_message = "primary_create_mode must be Default, PointInTimeRestore, GeoRestore, ReviveDropped, Replica, or Update."
  }
}

variable "primary_source_server_id" {
  description = "Source server ID for PointInTimeRestore, GeoRestore, Replica, or other source-based creation modes."
  type        = string
  default     = null
}

variable "primary_point_in_time_restore_time_in_utc" {
  description = "RFC3339 UTC restore timestamp for PointInTimeRestore or GeoRestore."
  type        = string
  default     = null
}

variable "create_dr_replica" {
  description = "CREATE the secondary server as a read replica of the primary for Active/Passive DR. Set false when not using replica mode."
  type        = bool
  default     = false
}


variable "create_secondary_server" {
  description = "CREATE a standalone secondary Flexible Server. Use this for a secondary-region-only deployment. Mutually exclusive with create_dr_replica."
  type        = bool
  default     = false
}

variable "existing_dr_server_id" {
  description = "Existing secondary/DR Flexible Server ID. Use this to reference an existing secondary server instead of creating one."
  type        = string
  default     = null
}

variable "dr_server_name" {
  description = "Name for a new secondary server, whether standalone or read replica."
  type        = string
  default     = null
}

# =============================================================================
# SERVER COMPUTE / STORAGE / BACKUP / HA / MAINTENANCE
# Null = do not explicitly configure the optional setting.
# =============================================================================
variable "postgresql_version" {
  description = "PostgreSQL major version for a newly created Default primary."
  type        = string
  default     = null

  validation {
    condition     = try(contains(["11", "12", "13", "14", "15", "16", "17", "18"], var.postgresql_version), true)
    error_message = "postgresql_version must be null or 11 through 18."
  }
}

variable "sku_name" {
  description = "Primary SKU. Required for create_mode=Default. Null otherwise means provider/service default where valid."
  type        = string
  default     = null
}

variable "dr_sku_name" {
  description = "Optional DR replica SKU override. Null lets Azure/provider inherit or determine the replica SKU."
  type        = string
  default     = null
}

variable "storage_mb" {
  description = "Primary storage size in MiB. Null means do not explicitly set."
  type        = number
  default     = null
}

variable "dr_storage_mb" {
  description = "Optional DR replica storage size in MiB."
  type        = number
  default     = null
}

variable "storage_tier" {
  description = "Primary storage tier such as P10/P20. Null means do not explicitly set."
  type        = string
  default     = null
}

variable "dr_storage_tier" {
  description = "Optional DR replica storage tier."
  type        = string
  default     = null
}

variable "auto_grow_enabled" {
  description = "Primary storage autogrow. Null = do not explicitly configure."
  type        = bool
  default     = null
}

variable "dr_auto_grow_enabled" {
  description = "DR storage autogrow. Null = do not explicitly configure."
  type        = bool
  default     = null
}

variable "backup_retention_days" {
  description = "Native backup retention for a new primary. Null = provider/service default."
  type        = number
  default     = null

  validation {
    condition     = try(var.backup_retention_days >= 7 && var.backup_retention_days <= 35, true)
    error_message = "backup_retention_days must be null or between 7 and 35."
  }
}

variable "geo_redundant_backup_enabled" {
  description = "Enable geo-redundant native backup on the primary where supported. Null = do not explicitly configure."
  type        = bool
  default     = null
}

variable "dr_backup_retention_days" {
  description = "Native backup retention for a standalone secondary server. Null = provider/service default. Not applicable to a read replica."
  type        = number
  default     = null

  validation {
    condition     = try(var.dr_backup_retention_days >= 7 && var.dr_backup_retention_days <= 35, true)
    error_message = "dr_backup_retention_days must be null or between 7 and 35."
  }
}

variable "dr_geo_redundant_backup_enabled" {
  description = "Enable geo-redundant native backup on a standalone secondary where supported. US Gov Texas currently does not support geo-redundant backup."
  type        = bool
  default     = null
}

variable "primary_zone" {
  description = "Optional primary availability zone."
  type        = string
  default     = null
}

variable "dr_zone" {
  description = "Optional DR availability zone."
  type        = string
  default     = null
}

variable "primary_high_availability" {
  description = "Optional primary HA block. Null = HA not configured by this module."
  type = object({
    mode                      = string
    standby_availability_zone = optional(string)
  })
  default = null

  validation {
    condition     = try(contains(["SameZone", "ZoneRedundant"], var.primary_high_availability.mode), true)
    error_message = "primary_high_availability.mode must be SameZone or ZoneRedundant."
  }
}

variable "dr_high_availability" {
  description = "Optional HA block for a standalone secondary server. Not supported on a read replica. US Gov Texas currently supports SameZone HA but not ZoneRedundant HA."
  type = object({
    mode                      = string
    standby_availability_zone = optional(string)
  })
  default = null

  validation {
    condition     = try(contains(["SameZone", "ZoneRedundant"], var.dr_high_availability.mode), true)
    error_message = "dr_high_availability.mode must be SameZone or ZoneRedundant."
  }
}

variable "dr_maintenance_window" {
  description = "Optional custom maintenance window for a standalone secondary server."
  type = object({
    day_of_week  = number
    start_hour   = number
    start_minute = number
  })
  default = null

  validation {
    condition = try(
      var.dr_maintenance_window.day_of_week >= 0 && var.dr_maintenance_window.day_of_week <= 6 &&
      var.dr_maintenance_window.start_hour >= 0 && var.dr_maintenance_window.start_hour <= 23 &&
      var.dr_maintenance_window.start_minute >= 0 && var.dr_maintenance_window.start_minute <= 59,
      true
    )
    error_message = "dr_maintenance_window values are out of range."
  }
}

variable "maintenance_window" {
  description = "Optional custom maintenance window. Null = not configured by this module."
  type = object({
    day_of_week  = number
    start_hour   = number
    start_minute = number
  })
  default = null

  validation {
    condition = try(
      var.maintenance_window.day_of_week >= 0 && var.maintenance_window.day_of_week <= 6 &&
      var.maintenance_window.start_hour >= 0 && var.maintenance_window.start_hour <= 23 &&
      var.maintenance_window.start_minute >= 0 && var.maintenance_window.start_minute <= 59,
      true
    )
    error_message = "maintenance_window must use day_of_week 0-6, start_hour 0-23, and start_minute 0-59."
  }
}

variable "elastic_cluster" {
  description = "Optional PostgreSQL Flexible Server cluster block. Null = disabled. Validate Azure Government/SKU support before enabling."
  type = object({
    size                  = number
    default_database_name = optional(string)
  })
  default = null

  validation {
    condition     = try(var.elastic_cluster.size >= 1 && var.elastic_cluster.size <= 20, true)
    error_message = "elastic_cluster.size must be between 1 and 20."
  }
}

# =============================================================================
# AUTHENTICATION / IDENTITY / CMK
# =============================================================================
variable "authentication" {
  description = "Authentication configuration for a new Default primary. Null = no auth block."
  type = object({
    password_auth_enabled         = bool
    active_directory_auth_enabled = bool
    tenant_id                     = optional(string)
  })
  default = null
}

variable "administrator_login" {
  description = "Administrator login for password-authenticated Default creation."
  type        = string
  default     = null
}

variable "administrator_password" {
  description = "Sensitive administrator password. Provide through TF_VAR_administrator_password or a pipeline secret; do not store it in sample.tfvars."
  type        = string
  sensitive   = true
  default     = null
}


variable "create_primary_user_assigned_identity" {
  description = "CREATE a primary UAMI. false + existing_primary_user_assigned_identity_id supplied = USE EXISTING; otherwise the resource is not managed."
  type        = bool
  default     = false
}

variable "primary_user_assigned_identity_name" {
  description = "Name of the primary UAMI when created."
  type        = string
  default     = null
}

variable "existing_primary_user_assigned_identity_id" {
  description = "Existing primary UAMI resource ID."
  type        = string
  default     = null
}

variable "primary_system_assigned_identity_enabled" {
  description = "Enable system-assigned identity on a newly created primary."
  type        = bool
  default     = false
}

variable "create_dr_user_assigned_identity" {
  description = "CREATE a DR UAMI. false + existing_dr_user_assigned_identity_id supplied = USE EXISTING; otherwise the resource is not managed."
  type        = bool
  default     = false
}

variable "dr_user_assigned_identity_name" {
  description = "Name of the DR UAMI when created."
  type        = string
  default     = null
}

variable "existing_dr_user_assigned_identity_id" {
  description = "Existing DR UAMI resource ID."
  type        = string
  default     = null
}

variable "dr_system_assigned_identity_enabled" {
  description = "Enable system-assigned identity on a newly created DR server/replica where supported."
  type        = bool
  default     = false
}

variable "primary_customer_managed_key" {
  description = "Optional primary CMK configuration. Null = Microsoft-managed encryption. key_vault_key_id may be omitted to use only the module-created/supplied PRIMARY regional Key Vault key."
  type = object({
    key_vault_key_id                     = optional(string)
    primary_user_assigned_identity_id    = optional(string)
    geo_backup_key_vault_key_id          = optional(string)
    geo_backup_user_assigned_identity_id = optional(string)
  })
  default = null
}

variable "dr_customer_managed_key" {
  description = "Optional DR CMK configuration. Null = Microsoft-managed encryption. key_vault_key_id may be omitted to use only the module-created/supplied DR regional Key Vault key."
  type = object({
    key_vault_key_id                     = optional(string)
    primary_user_assigned_identity_id    = optional(string)
    geo_backup_key_vault_key_id          = optional(string)
    geo_backup_user_assigned_identity_id = optional(string)
  })
  default = null
}

variable "entra_administrators" {
  description = "Microsoft Entra administrators to manage on the effective primary. Empty map = not configured."
  type = map(object({
    object_id      = string
    principal_name = string
    principal_type = string
    tenant_id      = optional(string)
  }))
  default = {}
}

variable "manage_entra_administrators_on_dr" {
  description = "Apply the same entra_administrators map to the effective DR server."
  type        = bool
  default     = false
}

# =============================================================================
# NETWORKING
# networking_mode null means no server is created; when a server is created an
# explicit mode is required so the module never guesses public/private intent.
# =============================================================================
variable "networking_mode" {
  description = "Primary networking mode: private_endpoint, vnet_integration, public, or null."
  type        = string
  default     = null

  validation {
    condition     = try(contains(["private_endpoint", "vnet_integration", "public"], var.networking_mode), true)
    error_message = "networking_mode must be null, private_endpoint, vnet_integration, or public."
  }
}

variable "dr_networking_mode" {
  description = "DR networking mode: private_endpoint, vnet_integration, public, or null."
  type        = string
  default     = null

  validation {
    condition     = try(contains(["private_endpoint", "vnet_integration", "public"], var.dr_networking_mode), true)
    error_message = "dr_networking_mode must be null, private_endpoint, vnet_integration, or public."
  }
}

variable "create_primary_networking" {
  description = "CREATE the primary VNet and the subnet required by networking_mode. false + IDs supplied = USE EXISTING; otherwise the resource is not managed."
  type        = bool
  default     = false
}

variable "create_dr_networking" {
  description = "CREATE the DR VNet and the subnet required by dr_networking_mode. false + IDs supplied = USE EXISTING; otherwise the resource is not managed."
  type        = bool
  default     = false
}

variable "primary_vnet_name" {
  description = "Primary VNet name when create_primary_networking=true."
  type        = string
  default     = null
}

variable "primary_vnet_address_space" {
  description = "Primary VNet address space when created."
  type        = list(string)
  default     = []
}

variable "primary_vnet_id" {
  description = "Existing primary VNet ID when networking is not created by this module."
  type        = string
  default     = null
}

variable "primary_private_endpoint_subnet_name" {
  description = "Primary PE subnet name when networking_mode=private_endpoint and networking is created."
  type        = string
  default     = null
}

variable "primary_private_endpoint_subnet_prefixes" {
  description = "Primary PE subnet prefixes when created."
  type        = list(string)
  default     = []
}

variable "primary_private_endpoint_subnet_id" {
  description = "Existing primary PE subnet ID."
  type        = string
  default     = null
}

variable "primary_delegated_subnet_name" {
  description = "Primary delegated subnet name when networking_mode=vnet_integration and networking is created."
  type        = string
  default     = null
}

variable "primary_delegated_subnet_prefixes" {
  description = "Primary delegated subnet prefixes when created."
  type        = list(string)
  default     = []
}

variable "primary_delegated_subnet_id" {
  description = "Existing primary delegated subnet ID for VNet integration."
  type        = string
  default     = null
}

variable "dr_vnet_name" {
  description = "DR VNet name when create_dr_networking=true."
  type        = string
  default     = null
}

variable "dr_vnet_address_space" {
  description = "DR VNet address space when created."
  type        = list(string)
  default     = []
}

variable "dr_vnet_id" {
  description = "Existing DR VNet ID."
  type        = string
  default     = null
}

variable "dr_private_endpoint_subnet_name" {
  description = "DR PE subnet name when dr_networking_mode=private_endpoint and networking is created."
  type        = string
  default     = null
}

variable "dr_private_endpoint_subnet_prefixes" {
  description = "DR PE subnet prefixes when created."
  type        = list(string)
  default     = []
}

variable "dr_private_endpoint_subnet_id" {
  description = "Existing DR PE subnet ID."
  type        = string
  default     = null
}

variable "dr_delegated_subnet_name" {
  description = "DR delegated subnet name when dr_networking_mode=vnet_integration and networking is created."
  type        = string
  default     = null
}

variable "dr_delegated_subnet_prefixes" {
  description = "DR delegated subnet prefixes when created."
  type        = list(string)
  default     = []
}

variable "dr_delegated_subnet_id" {
  description = "Existing DR delegated subnet ID for VNet integration."
  type        = string
  default     = null
}

# =============================================================================
# PRIVATE DNS - CREATE NEW / USE EXISTING
# =============================================================================
variable "create_private_dns_zone" {
  description = "CREATE the private DNS zone. false + existing_private_dns_zone_id supplied = USE EXISTING; otherwise the resource is not managed."
  type        = bool
  default     = false
}

variable "private_dns_zone_name" {
  description = "Private DNS zone name when created. For Azure Gov Private Link the standard zone is privatelink.postgres.database.usgovcloudapi.net."
  type        = string
  default     = null
}

variable "private_dns_zone_resource_group_name" {
  description = "Resource group for a newly created Private DNS zone."
  type        = string
  default     = null
}

variable "existing_private_dns_zone_id" {
  description = "Existing Private DNS zone ID."
  type        = string
  default     = null
}

variable "private_dns_vnet_links" {
  description = "DNS VNet links to create. Use vnet_id='primary' or 'dr' to reference module/effective VNets, or supply a full VNet ID. Empty map = not configured."
  type = map(object({
    name    = string
    vnet_id = string
  }))
  default = {}
}

# =============================================================================
# VNET-INTEGRATION PRIVATE DNS - SEPARATE FROM PRIVATE LINK DNS
# =============================================================================
variable "create_vnet_integration_private_dns_zone" {
  description = "CREATE the Private DNS zone used by delegated-subnet VNet integration. This is separate from the Private Link zone."
  type        = bool
  default     = false
}

variable "vnet_integration_private_dns_zone_name" {
  description = "Private DNS zone name for VNet integration. It must end in .postgres.database.azure.com."
  type        = string
  default     = null
}

variable "vnet_integration_private_dns_zone_resource_group_name" {
  description = "Resource group for a newly created VNet-integration Private DNS zone."
  type        = string
  default     = null
}

variable "existing_vnet_integration_private_dns_zone_id" {
  description = "Existing Private DNS zone ID for delegated-subnet VNet integration."
  type        = string
  default     = null
}

variable "vnet_integration_dns_vnet_links" {
  description = "VNet links for the VNet-integration DNS zone. Use vnet_id='primary' or 'dr', or provide a full VNet ID."
  type = map(object({
    name    = string
    vnet_id = string
  }))
  default = {}
}

# =============================================================================
# PRIVATE ENDPOINTS - CREATE NEW / USE EXISTING
# =============================================================================
variable "create_primary_private_endpoint" {
  description = "CREATE primary PostgreSQL Private Endpoint. false + existing_primary_private_endpoint_id supplied = USE EXISTING; otherwise the resource is not managed."
  type        = bool
  default     = false
}

variable "existing_primary_private_endpoint_id" {
  description = "Existing primary PostgreSQL Private Endpoint ID."
  type        = string
  default     = null
}

variable "primary_private_endpoint_name" {
  description = "Primary Private Endpoint name when created."
  type        = string
  default     = null
}

variable "create_dr_private_endpoint" {
  description = "CREATE DR PostgreSQL Private Endpoint. false + existing_dr_private_endpoint_id supplied = USE EXISTING; otherwise the resource is not managed."
  type        = bool
  default     = false
}

variable "existing_dr_private_endpoint_id" {
  description = "Existing DR PostgreSQL Private Endpoint ID."
  type        = string
  default     = null
}

variable "dr_private_endpoint_name" {
  description = "DR Private Endpoint name when created."
  type        = string
  default     = null
}

variable "private_endpoint_attach_dns_zone" {
  description = "Attach the effective private DNS zone to Private Endpoint DNS zone groups. false = create PE without DNS zone group."
  type        = bool
  default     = false
}

# =============================================================================
# DATABASES / SERVER PARAMETERS / EXTENSIONS / PGBOUNCER / FIREWALL
# =============================================================================
variable "database_definitions" {
  description = "Databases to create on the effective primary. Empty map = not configured."
  type = map(object({
    charset   = optional(string, "UTF8")
    collation = optional(string, "en_US.utf8")
  }))
  default = {}
}

variable "secondary_database_definitions" {
  description = "Databases to create on a standalone secondary server. Keep empty for Active/Passive read-replica mode because databases replicate from the primary."
  type = map(object({
    charset   = optional(string, "UTF8")
    collation = optional(string, "en_US.utf8")
  }))
  default = {}
}


variable "server_parameters" {
  description = "Flexible Server configuration parameters on the effective primary. Empty map = not configured."
  type        = map(string)
  default     = {}
}

variable "primary_server_parameter_overrides" {
  description = "Primary-only server parameter overrides. Empty map = not configured."
  type        = map(string)
  default     = {}
}

variable "apply_server_parameters_to_dr" {
  description = "Apply the primary effective parameter set to the effective DR server."
  type        = bool
  default     = false
}

variable "dr_server_parameter_overrides" {
  description = "DR-only server parameter overrides. Empty map = not configured."
  type        = map(string)
  default     = {}
}

variable "extensions" {
  description = "Extension names to allowlist through azure.extensions on the primary. Empty set = not configured."
  type        = set(string)
  default     = []
}

variable "pgbouncer_enabled" {
  description = "Manage pgbouncer.enabled. Null = not configured; true/false explicitly sets the parameter."
  type        = bool
  default     = null
}

variable "firewall_rules" {
  description = "Firewall rules. target must be primary or dr. Empty map = not configured. Intended for public networking only."
  type = map(object({
    target           = string
    start_ip_address = string
    end_ip_address   = string
  }))
  default = {}

  validation {
    condition     = alltrue([for rule in values(var.firewall_rules) : contains(["primary", "dr"], rule.target)])
    error_message = "Each firewall_rules.target must be primary or dr."
  }
}

# =============================================================================
# ADDITIONAL READ REPLICAS / VIRTUAL ENDPOINTS / ON-DEMAND BACKUPS
# =============================================================================
variable "additional_read_replicas" {
  description = "Additional direct read replicas. Empty map = NOT CONFIGURED. Supports public, VNet integration, or Private Endpoint networking plus optional per-replica CMK/UAMI. Azure supports up to 5 direct read replicas per source; create_dr_replica also consumes one direct-replica slot."

  type = map(object({
    name                = string
    resource_group_name = string
    location            = string
    networking_mode     = string

    # VNet integration
    delegated_subnet_id = optional(string)
    private_dns_zone_id = optional(string)

    # Compute / storage
    sku_name          = optional(string)
    storage_mb        = optional(number)
    storage_tier      = optional(string)
    auto_grow_enabled = optional(bool)
    zone              = optional(string)

    # CMK / Identity
    system_assigned_identity_enabled = optional(bool, false)
    user_assigned_identity_id        = optional(string)
    key_vault_key_id                 = optional(string)

    # Private Endpoint
    create_private_endpoint          = optional(bool, false)
    existing_private_endpoint_id     = optional(string)
    private_endpoint_name            = optional(string)
    private_endpoint_subnet_id       = optional(string)
    private_endpoint_attach_dns_zone = optional(bool, true)

    # Diagnostics
    enable_diagnostics = optional(bool, false)

    tags = optional(map(string), {})
  }))

  default = {}

  validation {
    condition = alltrue([
      for replica in values(var.additional_read_replicas) :
      contains(
        ["private_endpoint", "vnet_integration", "public"],
        replica.networking_mode
      )
    ])

    error_message = "Each additional_read_replicas.networking_mode must be private_endpoint, vnet_integration, or public."
  }

  validation {
    condition = alltrue([
      for replica in values(var.additional_read_replicas) :
      replica.networking_mode != "vnet_integration" || (
        try(replica.delegated_subnet_id, null) != null &&
        try(replica.private_dns_zone_id, null) != null
      )
    ])

    error_message = "A VNet-integrated additional replica requires delegated_subnet_id and private_dns_zone_id."
  }

  validation {
    condition = alltrue([
      for replica in values(var.additional_read_replicas) :
      !try(replica.create_private_endpoint, false) || (
        replica.networking_mode == "private_endpoint" &&
        try(replica.private_endpoint_name, null) != null &&
        try(replica.private_endpoint_subnet_id, null) != null
      )
    ])

    error_message = "Creating an additional-replica Private Endpoint requires networking_mode=private_endpoint, private_endpoint_name, and private_endpoint_subnet_id."
  }

  validation {
    condition = alltrue([
      for replica in values(var.additional_read_replicas) :
      !(
        try(replica.create_private_endpoint, false) &&
        try(replica.existing_private_endpoint_id, null) != null
      )
    ])

    error_message = "Choose CREATE or USE EXISTING for an additional-replica Private Endpoint, not both."
  }

  validation {
    condition = alltrue([
      for replica in values(var.additional_read_replicas) :
      try(replica.key_vault_key_id, null) == null ||
      try(replica.user_assigned_identity_id, null) != null
    ])

    error_message = "An additional replica using CMK requires user_assigned_identity_id together with key_vault_key_id."
  }
}

variable "virtual_endpoints" {
  description = "Virtual endpoints to create between the effective primary and DR servers. type is ReadWrite or ReadOnly. Empty map = not configured."
  type = map(object({
    name = string
    type = string
  }))
  default = {}

  validation {
    condition     = alltrue([for endpoint in values(var.virtual_endpoints) : contains(["ReadWrite", "ReadOnly"], endpoint.type)])
    error_message = "virtual_endpoints.type must be ReadWrite or ReadOnly."
  }
}

variable "existing_virtual_endpoint_ids" {
  description = "Optional IDs of existing virtual endpoints to surface in outputs without recreating them. Empty map = not configured."
  type        = map(string)
  default     = {}
}

variable "on_demand_backups" {
  description = "On-demand backups to create. target must be primary or dr. Empty map = not configured."
  type = map(object({
    name   = string
    target = string
  }))
  default = {}

  validation {
    condition     = alltrue([for backup in values(var.on_demand_backups) : contains(["primary", "dr"], backup.target)])
    error_message = "on_demand_backups.target must be primary or dr."
  }
}

# =============================================================================
# MONITORING - LOG ANALYTICS CREATE NEW / USE EXISTING + DIAGNOSTICS/ALERTS
# =============================================================================
variable "create_log_analytics_workspace" {
  description = "CREATE a Log Analytics workspace. false + existing_log_analytics_workspace_id supplied = USE EXISTING; otherwise the resource is not managed."
  type        = bool
  default     = false
}

variable "existing_log_analytics_workspace_id" {
  description = "Existing Log Analytics workspace ID."
  type        = string
  default     = null
}

variable "log_analytics_workspace_name" {
  description = "Workspace name when created."
  type        = string
  default     = null
}

variable "log_analytics_resource_group_name" {
  description = "Workspace resource group when created."
  type        = string
  default     = null
}

variable "log_analytics_location" {
  description = "Workspace location when created."
  type        = string
  default     = null
}

variable "log_analytics_retention_days" {
  description = "Workspace retention days when created."
  type        = number
  default     = 30
}

variable "enable_primary_diagnostics" {
  description = "Create diagnostic settings for the effective primary server."
  type        = bool
  default     = false
}

variable "enable_dr_diagnostics" {
  description = "Create diagnostic settings for the effective DR server."
  type        = bool
  default     = false
}

variable "diagnostic_storage_account_id" {
  description = "Optional Storage Account destination for diagnostic settings."
  type        = string
  default     = null
}

variable "diagnostic_eventhub_name" {
  description = "Optional Event Hub name for diagnostic settings."
  type        = string
  default     = null
}

variable "diagnostic_eventhub_authorization_rule_id" {
  description = "Optional Event Hub authorization rule ID for diagnostic settings."
  type        = string
  default     = null
}

variable "diagnostic_log_categories" {
  description = "Diagnostic log categories. Empty set means discover and enable all supported log categories when diagnostics are enabled."
  type        = set(string)
  default     = []
}

variable "diagnostic_metric_categories" {
  description = "Diagnostic metric categories. Empty set means discover and enable all supported metric categories when diagnostics are enabled."
  type        = set(string)
  default     = []
}

variable "metric_alerts" {
  description = "Metric alerts for primary/dr servers. Empty map = not configured."
  type = map(object({
    target                   = string
    metric_name              = string
    aggregation              = string
    operator                 = string
    threshold                = number
    severity                 = optional(number, 2)
    frequency                = optional(string, "PT5M")
    window_size              = optional(string, "PT5M")
    description              = optional(string)
    action_group_ids         = optional(set(string), [])
    use_default_action_group = optional(bool, false)
  }))
  default = {}

  validation {
    condition     = alltrue([for alert in values(var.metric_alerts) : contains(["primary", "dr"], alert.target)])
    error_message = "metric_alerts.target must be primary or dr."
  }
}


# =============================================================================
# PORTAL / ENTERPRISE OPTIONAL FEATURES
# Omitted/null/empty means NOT CONFIGURED. Explicit management preserves CREATE/EXISTING.
# =============================================================================
variable "query_store" {
  description = "Friendly Query Store / Query Performance Insight configuration for the primary. Null = NOT CONFIGURED. Not supported for Elastic Cluster."
  type = object({
    enabled                          = bool
    query_capture_mode               = optional(string, "top")
    wait_sampling_query_capture_mode = optional(string, "all")
    retention_period_in_days         = optional(number)
    store_query_plans                = optional(bool)
  })
  default = null

  validation {
    condition = try(
      contains(["top", "all"], lower(var.query_store.query_capture_mode)) &&
      contains(["top", "all"], lower(var.query_store.wait_sampling_query_capture_mode)) &&
      try(var.query_store.retention_period_in_days >= 1 && var.query_store.retention_period_in_days <= 30, true),
      true
    )
    error_message = "query_store capture modes must be top/all and retention_period_in_days must be 1-30 when supplied. Set enabled=false to explicitly disable Query Store."
  }
}

variable "autonomous_tuning" {
  description = "Friendly Autonomous Tuning configuration for the primary. Null = NOT CONFIGURED. enabled=true emits index tuning recommendations; read replicas and Elastic Cluster are not targeted."
  type = object({
    enabled                = bool
    analysis_interval      = optional(number, 720)
    max_columns_per_index  = optional(number)
    max_index_count        = optional(number)
    max_indexes_per_table  = optional(number)
    min_improvement_factor = optional(number)
  })
  default = null

  validation {
    condition = try(
      try(var.autonomous_tuning.analysis_interval, 720) >= 60 && try(var.autonomous_tuning.analysis_interval, 720) <= 10080 &&
      try(var.autonomous_tuning.max_columns_per_index >= 1 && var.autonomous_tuning.max_columns_per_index <= 10, true) &&
      try(var.autonomous_tuning.max_index_count >= 1 && var.autonomous_tuning.max_index_count <= 25, true) &&
      try(var.autonomous_tuning.max_indexes_per_table >= 1 && var.autonomous_tuning.max_indexes_per_table <= 25, true) &&
      try(var.autonomous_tuning.min_improvement_factor >= 0 && var.autonomous_tuning.min_improvement_factor <= 20, true),
      true
    )
    error_message = "autonomous_tuning values are outside the documented ranges."
  }
}

variable "logging" {
  description = "Friendly PostgreSQL server logging configuration on the primary. Null = NOT CONFIGURED. Generic server_parameters can still be used for additional settings."
  type = object({
    log_connections             = optional(bool)
    log_disconnections          = optional(bool)
    log_checkpoints             = optional(bool)
    log_duration                = optional(bool)
    log_lock_waits              = optional(bool)
    log_min_duration_statement  = optional(number)
    log_autovacuum_min_duration = optional(number)
    log_temp_files              = optional(number)
    log_statement               = optional(string)
  })
  default = null
}

# Defender is intentionally null by default because the subscription plan can affect
# every open-source relational database in the subscription and can affect cost.
variable "defender_subscription_plan_tier" {
  description = "Manage the subscription Defender plan for OpenSourceRelationalDatabases. null = preserve existing / do not manage; Standard = enable; Free = disable paid plan."
  type        = string
  default     = null

  validation {
    condition     = try(contains(["Free", "Standard"], var.defender_subscription_plan_tier), true)
    error_message = "defender_subscription_plan_tier must be null, Free, or Standard."
  }
}

variable "primary_defender_threat_protection_state" {
  description = "Resource-level PostgreSQL advanced threat protection state. null = preserve existing / do not manage; Enabled/Disabled = manage explicitly through AzAPI."
  type        = string
  default     = null

  validation {
    condition     = try(contains(["Enabled", "Disabled"], var.primary_defender_threat_protection_state), true)
    error_message = "primary_defender_threat_protection_state must be null, Enabled, or Disabled."
  }
}

variable "dr_defender_threat_protection_state" {
  description = "Resource-level DR PostgreSQL advanced threat protection state. null = preserve existing / do not manage; Enabled/Disabled = manage explicitly through AzAPI."
  type        = string
  default     = null

  validation {
    condition     = try(contains(["Enabled", "Disabled"], var.dr_defender_threat_protection_state), true)
    error_message = "dr_defender_threat_protection_state must be null, Enabled, or Disabled."
  }
}

# Azure Backup / Long-Term Retention
variable "create_backup_vault" {
  description = "CREATE an Azure Data Protection Backup Vault for PostgreSQL LTR. false + existing_backup_vault_id = USE EXISTING; otherwise the resource is not managed."
  type        = bool
  default     = false
}

variable "existing_backup_vault_id" {
  description = "Existing Backup Vault resource ID. Null + create_backup_vault=false means no Backup Vault is managed."
  type        = string
  default     = null
}

variable "existing_backup_vault_principal_id" {
  description = "System-assigned identity principal ID of an existing Backup Vault. Required only when this module manages LTR role assignments for an existing vault."
  type        = string
  default     = null
}

variable "backup_vault_name" {
  description = "Backup Vault name when created."
  type        = string
  default     = null
}

variable "backup_vault_resource_group_name" {
  description = "Backup Vault resource group name when created."
  type        = string
  default     = null
}

variable "backup_vault_location" {
  description = "Backup Vault location when created."
  type        = string
  default     = null
}

variable "backup_vault_redundancy" {
  description = "Backup Vault redundancy when created."
  type        = string
  default     = null

  validation {
    condition     = try(contains(["GeoRedundant", "LocallyRedundant", "ZoneRedundant"], var.backup_vault_redundancy), true)
    error_message = "backup_vault_redundancy must be GeoRedundant, LocallyRedundant, ZoneRedundant, or null."
  }
}

variable "backup_vault_cross_region_restore_enabled" {
  description = "Optional cross-region restore setting for a GeoRedundant Backup Vault. Null = use the provider default and do not explicitly configure this setting."
  type        = bool
  default     = null
}

variable "backup_vault_soft_delete" {
  description = "Optional Backup Vault soft delete state: AlwaysOn, Off, or On. Null = provider default."
  type        = string
  default     = null

  validation {
    condition     = try(contains(["AlwaysOn", "Off", "On"], var.backup_vault_soft_delete), true)
    error_message = "backup_vault_soft_delete must be null, AlwaysOn, Off, or On."
  }
}

variable "backup_vault_retention_duration_in_days" {
  description = "Optional Backup Vault soft-delete retention, 14-180 days. Null = provider default."
  type        = number
  default     = null

  validation {
    condition     = try(var.backup_vault_retention_duration_in_days >= 14 && var.backup_vault_retention_duration_in_days <= 180, true)
    error_message = "backup_vault_retention_duration_in_days must be null or 14-180."
  }
}

variable "create_backup_policy" {
  description = "CREATE a PostgreSQL Flexible Server LTR backup policy. false + existing_backup_policy_id = USE EXISTING; otherwise the resource is not managed."
  type        = bool
  default     = false
}

variable "existing_backup_policy_id" {
  description = "Existing PostgreSQL Flexible Server backup policy ID."
  type        = string
  default     = null
}

variable "backup_policy_name" {
  description = "LTR backup policy name when created."
  type        = string
  default     = null
}

variable "backup_repeating_time_intervals" {
  description = "Weekly ISO 8601 repeating intervals for PostgreSQL Flexible Server LTR policy. Empty = no policy creation input."
  type        = list(string)
  default     = []
}

variable "backup_policy_time_zone" {
  description = "Optional time zone for LTR backup policy."
  type        = string
  default     = null
}

variable "backup_policy_default_retention_duration" {
  description = "ISO 8601 duration for the default LTR retention rule, e.g. P4M or P7Y."
  type        = string
  default     = null
}

variable "backup_policy_retention_rules" {
  description = "Optional named LTR retention rules. Empty map = only default rule."
  type = map(object({
    priority               = number
    duration               = string
    absolute_criteria      = optional(string)
    days_of_week           = optional(set(string), [])
    months_of_year         = optional(set(string), [])
    weeks_of_month         = optional(set(string), [])
    scheduled_backup_times = optional(set(string), [])
  }))
  default = {}
}

variable "create_ltr_backup_instance" {
  description = "CREATE Azure Backup protection for the effective primary server. false + existing_ltr_backup_instance_id = USE EXISTING/surface; otherwise the resource is not managed."
  type        = bool
  default     = false
}

variable "existing_ltr_backup_instance_id" {
  description = "Existing PostgreSQL Flexible Server Backup Instance ID."
  type        = string
  default     = null
}

variable "ltr_backup_instance_name" {
  description = "Backup Instance name when created."
  type        = string
  default     = null
}

variable "ltr_backup_instance_location" {
  description = "Backup Instance source database location. Null uses primary_location when creating."
  type        = string
  default     = null
}

variable "manage_ltr_role_assignments" {
  description = "Create the documented Reader + PostgreSQL Flexible Server Long Term Retention Backup Role assignments for the Backup Vault identity."
  type        = bool
  default     = false
}

# Azure Monitor Action Group - CREATE NEW / USE EXISTING
variable "create_monitor_action_group" {
  description = "CREATE a default Azure Monitor Action Group. false + existing_monitor_action_group_id = USE EXISTING; otherwise the resource is not managed."
  type        = bool
  default     = false
}

variable "existing_monitor_action_group_id" {
  description = "Existing Azure Monitor Action Group ID."
  type        = string
  default     = null
}

variable "monitor_action_group_name" {
  description = "Action Group name when created."
  type        = string
  default     = null
}

variable "monitor_action_group_resource_group_name" {
  description = "Action Group resource group when created."
  type        = string
  default     = null
}

variable "monitor_action_group_short_name" {
  description = "Action Group short name when created."
  type        = string
  default     = null
}

variable "monitor_action_group_location" {
  description = "Optional Action Group location. Null uses provider default (global)."
  type        = string
  default     = null
}

variable "monitor_action_group_enabled" {
  description = "Optional explicit Action Group enabled state. Null = provider default."
  type        = bool
  default     = null
}

variable "action_group_email_receivers" {
  description = "Email receivers for a created Action Group. Empty map = none."
  type = map(object({
    email_address           = string
    use_common_alert_schema = optional(bool)
  }))
  default = {}
}

variable "action_group_sms_receivers" {
  description = "SMS receivers for a created Action Group. Empty map = none."
  type = map(object({
    country_code = string
    phone_number = string
  }))
  default = {}
}

variable "action_group_webhook_receivers" {
  description = "Webhook receivers for a created Action Group. Empty map = none."
  type = map(object({
    service_uri             = string
    use_common_alert_schema = optional(bool)
  }))
  default = {}
}

# Azure Monitor Workbook - CREATE NEW / USE EXISTING
variable "create_monitor_workbook" {
  description = "CREATE an Azure Monitor Workbook. false + existing_monitor_workbook_id = USE EXISTING/surface; otherwise the resource is not managed."
  type        = bool
  default     = false
}

variable "existing_monitor_workbook_id" {
  description = "Existing Azure Monitor Workbook ID."
  type        = string
  default     = null
}

variable "monitor_workbook_name" {
  description = "Workbook resource name as a lowercase UUID/GUID."
  type        = string
  default     = null
}

variable "monitor_workbook_resource_group_name" {
  description = "Workbook resource group name."
  type        = string
  default     = null
}

variable "monitor_workbook_location" {
  description = "Workbook location."
  type        = string
  default     = null
}

variable "monitor_workbook_display_name" {
  description = "Workbook display name."
  type        = string
  default     = null
}

variable "monitor_workbook_data_json" {
  description = "Workbook configuration JSON string."
  type        = string
  default     = null
}

variable "monitor_workbook_source_id" {
  description = "Optional Workbook source resource ID."
  type        = string
  default     = null
}

# Advisor itself is Azure-generated; Terraform can optionally suppress recommendations.
variable "advisor_suppressions" {
  description = "Azure Advisor suppressions. Empty map = not configured."
  type = map(object({
    recommendation_id = string
    resource_id       = string
    ttl               = optional(string)
  }))
  default = {}
}

# Enterprise cross-region Key Vault / CMK support. Primary and DR are intentionally
# independent CREATE NEW / USE EXISTING / NOT CONFIGURED stacks.
variable "create_cmk_role_assignments" {
  description = "Backward-compatible master switch. When true, create both applicable regional Key Vault Crypto Service Encryption User assignments. Prefer the regional switches for new deployments."
  type        = bool
  default     = false
}

variable "create_primary_cmk_role_assignment" {
  description = "Create Key Vault Crypto Service Encryption User on the effective PRIMARY Key Vault for the effective primary PostgreSQL UAMI."
  type        = bool
  default     = false
}

variable "create_dr_cmk_role_assignment" {
  description = "Create Key Vault Crypto Service Encryption User on the effective DR Key Vault for the effective DR PostgreSQL UAMI."
  type        = bool
  default     = false
}

# =============================================================================
# PRIMARY KEY VAULT - CREATE NEW / USE EXISTING
# =============================================================================
variable "create_primary_key_vault" {
  description = "CREATE the primary-region Key Vault for PostgreSQL CMK. false + existing_primary_key_vault_id = USE EXISTING; otherwise not managed."
  type        = bool
  default     = false
}

variable "existing_primary_key_vault_id" {
  description = "Existing primary-region Key Vault resource ID."
  type        = string
  default     = null
}

variable "primary_key_vault_name" {
  description = "Primary-region Key Vault name when created."
  type        = string
  default     = null
}

variable "primary_key_vault_resource_group_name" {
  description = "Primary-region Key Vault resource group. Also used for a module-created primary Key Vault Private Endpoint."
  type        = string
  default     = null
}

variable "primary_key_vault_location" {
  description = "Primary-region Key Vault location. Typically the same as primary_location."
  type        = string
  default     = null
}

variable "primary_key_vault_sku_name" {
  description = "Primary-region Key Vault SKU."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.primary_key_vault_sku_name)
    error_message = "primary_key_vault_sku_name must be standard or premium."
  }
}

variable "primary_key_vault_rbac_authorization_enabled" {
  description = "Enable RBAC authorization on a module-created primary CMK Key Vault. Enterprise secure default is true."
  type        = bool
  default     = true
}

variable "primary_key_vault_purge_protection_enabled" {
  description = "Enable purge protection on a module-created primary CMK Key Vault."
  type        = bool
  default     = true
}

variable "primary_key_vault_public_network_access_enabled" {
  description = "Compatibility guard. main.tf hard-disables public access on a module-created primary CMK Key Vault; keep false."
  type        = bool
  default     = false

  validation {
    condition     = var.primary_key_vault_public_network_access_enabled != true
    error_message = "Public network access is not permitted for the primary PostgreSQL CMK Key Vault."
  }
}

variable "primary_key_vault_soft_delete_retention_days" {
  description = "Primary Key Vault soft-delete retention days, 7-90."
  type        = number
  default     = 90

  validation {
    condition     = var.primary_key_vault_soft_delete_retention_days >= 7 && var.primary_key_vault_soft_delete_retention_days <= 90
    error_message = "primary_key_vault_soft_delete_retention_days must be 7-90."
  }
}

variable "primary_key_vault_network_acls" {
  description = "Network ACLs for a module-created primary CMK Key Vault."
  type = object({
    bypass                     = optional(string, "AzureServices")
    default_action             = optional(string, "Deny")
    ip_rules                   = optional(list(string), [])
    virtual_network_subnet_ids = optional(list(string), [])
  })
  default = {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }

  validation {
    condition     = contains(["AzureServices", "None"], var.primary_key_vault_network_acls.bypass)
    error_message = "primary_key_vault_network_acls.bypass must be AzureServices or None."
  }

  validation {
    condition     = contains(["Allow", "Deny"], var.primary_key_vault_network_acls.default_action)
    error_message = "primary_key_vault_network_acls.default_action must be Allow or Deny."
  }
}

# =============================================================================
# DR KEY VAULT - CREATE NEW / USE EXISTING
# =============================================================================
variable "create_dr_key_vault" {
  description = "CREATE the DR-region Key Vault for PostgreSQL CMK. false + existing_dr_key_vault_id = USE EXISTING; otherwise not managed."
  type        = bool
  default     = false
}

variable "existing_dr_key_vault_id" {
  description = "Existing DR-region Key Vault resource ID."
  type        = string
  default     = null
}

variable "dr_key_vault_name" {
  description = "DR-region Key Vault name when created."
  type        = string
  default     = null
}

variable "dr_key_vault_resource_group_name" {
  description = "DR-region Key Vault resource group. Also used for a module-created DR Key Vault Private Endpoint."
  type        = string
  default     = null
}

variable "dr_key_vault_location" {
  description = "DR-region Key Vault location. Typically the same as dr_location."
  type        = string
  default     = null
}

variable "dr_key_vault_sku_name" {
  description = "DR-region Key Vault SKU."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.dr_key_vault_sku_name)
    error_message = "dr_key_vault_sku_name must be standard or premium."
  }
}

variable "dr_key_vault_rbac_authorization_enabled" {
  description = "Enable RBAC authorization on a module-created DR CMK Key Vault."
  type        = bool
  default     = true
}

variable "dr_key_vault_purge_protection_enabled" {
  description = "Enable purge protection on a module-created DR CMK Key Vault."
  type        = bool
  default     = true
}

variable "dr_key_vault_public_network_access_enabled" {
  description = "Compatibility guard. main.tf hard-disables public access on a module-created DR CMK Key Vault; keep false."
  type        = bool
  default     = false

  validation {
    condition     = var.dr_key_vault_public_network_access_enabled != true
    error_message = "Public network access is not permitted for the DR PostgreSQL CMK Key Vault."
  }
}

variable "dr_key_vault_soft_delete_retention_days" {
  description = "DR Key Vault soft-delete retention days, 7-90."
  type        = number
  default     = 90

  validation {
    condition     = var.dr_key_vault_soft_delete_retention_days >= 7 && var.dr_key_vault_soft_delete_retention_days <= 90
    error_message = "dr_key_vault_soft_delete_retention_days must be 7-90."
  }
}

variable "dr_key_vault_network_acls" {
  description = "Network ACLs for a module-created DR CMK Key Vault."
  type = object({
    bypass                     = optional(string, "AzureServices")
    default_action             = optional(string, "Deny")
    ip_rules                   = optional(list(string), [])
    virtual_network_subnet_ids = optional(list(string), [])
  })
  default = {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = []
    virtual_network_subnet_ids = []
  }

  validation {
    condition     = contains(["AzureServices", "None"], var.dr_key_vault_network_acls.bypass)
    error_message = "dr_key_vault_network_acls.bypass must be AzureServices or None."
  }

  validation {
    condition     = contains(["Allow", "Deny"], var.dr_key_vault_network_acls.default_action)
    error_message = "dr_key_vault_network_acls.default_action must be Allow or Deny."
  }
}

# =============================================================================
# PRIMARY / DR KEY VAULT PRIVATE DNS
# =============================================================================
variable "create_primary_key_vault_private_dns_zone" {
  description = "CREATE the primary Azure Government Key Vault Private DNS zone. false + existing ID = USE EXISTING."
  type        = bool
  default     = false
}
variable "existing_primary_key_vault_private_dns_zone_id" {
  description = "Existing primary Key Vault Private DNS zone ID."
  type        = string
  default     = null
}
variable "primary_key_vault_private_dns_zone_name" {
  description = "Primary Key Vault Private DNS zone. Azure Government standard is privatelink.vaultcore.usgovcloudapi.net."
  type        = string
  default     = "privatelink.vaultcore.usgovcloudapi.net"
}
variable "primary_key_vault_private_dns_zone_resource_group_name" {
  description = "Resource group for a newly created primary Key Vault Private DNS zone."
  type        = string
  default     = null
}
variable "create_primary_key_vault_private_dns_vnet_link" {
  description = "CREATE the link from the effective primary Key Vault Private DNS zone to the effective primary VNet."
  type        = bool
  default     = false
}
variable "primary_key_vault_private_dns_vnet_link_name" {
  description = "Primary Key Vault Private DNS VNet link name."
  type        = string
  default     = null
}

variable "create_dr_key_vault_private_dns_zone" {
  description = "CREATE the DR Azure Government Key Vault Private DNS zone. false + existing ID = USE EXISTING."
  type        = bool
  default     = false
}
variable "existing_dr_key_vault_private_dns_zone_id" {
  description = "Existing DR Key Vault Private DNS zone ID."
  type        = string
  default     = null
}
variable "dr_key_vault_private_dns_zone_name" {
  description = "DR Key Vault Private DNS zone. Azure Government standard is privatelink.vaultcore.usgovcloudapi.net."
  type        = string
  default     = "privatelink.vaultcore.usgovcloudapi.net"
}
variable "dr_key_vault_private_dns_zone_resource_group_name" {
  description = "Resource group for a newly created DR Key Vault Private DNS zone."
  type        = string
  default     = null
}
variable "create_dr_key_vault_private_dns_vnet_link" {
  description = "CREATE the link from the effective DR Key Vault Private DNS zone to the effective DR VNet."
  type        = bool
  default     = false
}
variable "dr_key_vault_private_dns_vnet_link_name" {
  description = "DR Key Vault Private DNS VNet link name."
  type        = string
  default     = null
}

# =============================================================================
# PRIMARY / DR KEY VAULT PRIVATE ENDPOINTS
# =============================================================================
variable "create_primary_key_vault_private_endpoint" {
  description = "CREATE a Private Endpoint for the effective primary CMK Key Vault. false + existing ID = USE EXISTING."
  type        = bool
  default     = false
}
variable "existing_primary_key_vault_private_endpoint_id" {
  description = "Existing primary Key Vault Private Endpoint ID."
  type        = string
  default     = null
}
variable "primary_key_vault_private_endpoint_name" {
  description = "Primary Key Vault Private Endpoint name."
  type        = string
  default     = null
}
variable "primary_key_vault_private_endpoint_subnet_id" {
  description = "Subnet ID for the primary Key Vault Private Endpoint. Null reuses the effective primary PostgreSQL PE subnet."
  type        = string
  default     = null
}

variable "create_dr_key_vault_private_endpoint" {
  description = "CREATE a Private Endpoint for the effective DR CMK Key Vault. false + existing ID = USE EXISTING."
  type        = bool
  default     = false
}
variable "existing_dr_key_vault_private_endpoint_id" {
  description = "Existing DR Key Vault Private Endpoint ID."
  type        = string
  default     = null
}
variable "dr_key_vault_private_endpoint_name" {
  description = "DR Key Vault Private Endpoint name."
  type        = string
  default     = null
}
variable "dr_key_vault_private_endpoint_subnet_id" {
  description = "Subnet ID for the DR Key Vault Private Endpoint. Null reuses the effective DR PostgreSQL PE subnet."
  type        = string
  default     = null
}

# =============================================================================
# PRIMARY / DR KEY VAULT KEYS
# =============================================================================
variable "create_primary_key_vault_key" {
  description = "CREATE the primary regional Key Vault CMK key. false + existing ID = USE EXISTING."
  type        = bool
  default     = false
}
variable "existing_primary_key_vault_key_id" {
  description = "Existing primary regional versionless or versioned Key Vault key ID."
  type        = string
  default     = null
}
variable "primary_key_vault_key_name" {
  description = "Primary regional CMK key name."
  type        = string
  default     = null
}
variable "primary_key_vault_key_type" {
  description = "Primary CMK key type: EC, EC-HSM, RSA, or RSA-HSM."
  type        = string
  default     = "RSA"
  validation {
    condition     = contains(["EC", "EC-HSM", "RSA", "RSA-HSM"], var.primary_key_vault_key_type)
    error_message = "primary_key_vault_key_type must be EC, EC-HSM, RSA, or RSA-HSM."
  }
}
variable "primary_key_vault_key_size" {
  description = "Primary RSA/RSA-HSM CMK size."
  type        = number
  default     = 4096
  validation {
    condition     = contains([2048, 3072, 4096], var.primary_key_vault_key_size)
    error_message = "primary_key_vault_key_size must be 2048, 3072, or 4096."
  }
}
variable "primary_key_vault_key_curve" {
  description = "Optional EC curve for the primary EC/EC-HSM CMK."
  type        = string
  default     = null
}
variable "primary_key_vault_key_opts" {
  description = "Primary CMK key operations."
  type        = set(string)
  default     = ["unwrapKey", "wrapKey"]
}

variable "create_dr_key_vault_key" {
  description = "CREATE the DR regional Key Vault CMK key. false + existing ID = USE EXISTING."
  type        = bool
  default     = false
}
variable "existing_dr_key_vault_key_id" {
  description = "Existing DR regional versionless or versioned Key Vault key ID."
  type        = string
  default     = null
}
variable "dr_key_vault_key_name" {
  description = "DR regional CMK key name."
  type        = string
  default     = null
}
variable "dr_key_vault_key_type" {
  description = "DR CMK key type: EC, EC-HSM, RSA, or RSA-HSM."
  type        = string
  default     = "RSA"
  validation {
    condition     = contains(["EC", "EC-HSM", "RSA", "RSA-HSM"], var.dr_key_vault_key_type)
    error_message = "dr_key_vault_key_type must be EC, EC-HSM, RSA, or RSA-HSM."
  }
}
variable "dr_key_vault_key_size" {
  description = "DR RSA/RSA-HSM CMK size."
  type        = number
  default     = 4096
  validation {
    condition     = contains([2048, 3072, 4096], var.dr_key_vault_key_size)
    error_message = "dr_key_vault_key_size must be 2048, 3072, or 4096."
  }
}
variable "dr_key_vault_key_curve" {
  description = "Optional EC curve for the DR EC/EC-HSM CMK."
  type        = string
  default     = null
}
variable "dr_key_vault_key_opts" {
  description = "DR CMK key operations."
  type        = set(string)
  default     = ["unwrapKey", "wrapKey"]
}

# =============================================================================
# GOVERNANCE - LOCKS / RBAC / TAGS
# =============================================================================
variable "primary_server_lock_level" {
  description = "Optional management lock on effective primary: CanNotDelete or ReadOnly. Null = NOT CONFIGURED."
  type        = string
  default     = null

  validation {
    condition     = try(contains(["CanNotDelete", "ReadOnly"], var.primary_server_lock_level), true)
    error_message = "primary_server_lock_level must be null, CanNotDelete, or ReadOnly."
  }
}

variable "dr_server_lock_level" {
  description = "Optional management lock on effective DR: CanNotDelete or ReadOnly. Null = NOT CONFIGURED."
  type        = string
  default     = null

  validation {
    condition     = try(contains(["CanNotDelete", "ReadOnly"], var.dr_server_lock_level), true)
    error_message = "dr_server_lock_level must be null, CanNotDelete, or ReadOnly."
  }
}

variable "role_assignments" {
  description = "RBAC assignments. scope can be primary_server, dr_server, private_dns_zone, log_analytics, primary_key_vault, dr_key_vault, backup_vault, action_group, or a full Azure resource ID. Empty map = not configured."
  type = map(object({
    scope                = string
    role_definition_name = string
    principal_id         = string
    principal_type       = optional(string)
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to resources created by this module. Empty map = no tags."
  type        = map(string)
  default     = {}
}

# =============================================================================
# CROSS-VARIABLE CHECKS - FAIL ONLY WHEN A FEATURE IS EXPLICITLY REQUESTED BUT
# REQUIRED INFORMATION IS MISSING. Omitted feature = NOT CONFIGURED.
# =============================================================================
check "resource_group_create_inputs" {
  assert {
    condition = (
      (!var.create_primary_resource_group || var.primary_resource_group_name != null) &&
      (!var.create_dr_resource_group || var.dr_resource_group_name != null)
    )
    error_message = "A resource group name is required only when its create_*_resource_group flag is true."
  }
}

check "primary_create_existing_conflict" {
  assert {
    condition     = !(var.create_primary_server && var.existing_primary_server_id != null)
    error_message = "Choose one primary mode: CREATE (create_primary_server=true) or USE EXISTING (existing_primary_server_id), not both."
  }
}

check "dr_create_existing_conflict" {
  assert {
    condition     = !((var.create_dr_replica || var.create_secondary_server) && var.existing_dr_server_id != null)
    error_message = "Choose CREATE NEW (replica or standalone secondary) or USE EXISTING (existing_dr_server_id), not both."
  }
}

check "secondary_create_mode" {
  assert {
    condition     = !(var.create_dr_replica && var.create_secondary_server)
    error_message = "Choose one secondary creation mode: standalone secondary (create_secondary_server=true) OR Active/Passive read replica (create_dr_replica=true), not both."
  }
}

check "secondary_create_existing_conflict" {
  assert {
    condition     = !((var.create_dr_replica || var.create_secondary_server) && var.existing_dr_server_id != null)
    error_message = "Choose CREATE NEW or USE EXISTING for the secondary server, not both."
  }
}

check "secondary_create_required_inputs" {
  assert {
    condition = (
      !var.create_secondary_server || (
        var.dr_server_name != null && var.dr_resource_group_name != null && var.dr_networking_mode != null &&
        var.postgresql_version != null && (var.dr_sku_name != null || var.sku_name != null) && var.authentication != null
      )
    )
    error_message = "Creating a standalone secondary requires dr_server_name, dr_resource_group_name, dr_networking_mode, postgresql_version, a DR or primary SKU, and authentication."
  }
}

check "secondary_password_auth_inputs" {
  assert {
    condition = try(
      !var.create_secondary_server || !var.authentication.password_auth_enabled || (
        var.administrator_login != null && var.administrator_password != null
      ),
      true
    )
    error_message = "A standalone secondary with password authentication requires administrator_login and administrator_password."
  }
}

check "secondary_ha_rules" {
  assert {
    condition     = try(var.dr_high_availability.mode != null ? (var.create_secondary_server && !var.create_dr_replica) : true, true)
    error_message = "Secondary HA can be configured only on a standalone secondary server. Azure PostgreSQL read replicas cannot have HA enabled."
  }
}

check "usgov_texas_zone_redundant_ha" {
  assert {
    condition     = try(lower(replace(var.dr_location, " ", "")) != "usgovtexas" || var.dr_high_availability.mode != "ZoneRedundant", true)
    error_message = "US Gov Texas currently supports SameZone HA but not ZoneRedundant HA for PostgreSQL Flexible Server."
  }
}

check "usgov_texas_geo_backup" {
  assert {
    condition     = var.dr_geo_redundant_backup_enabled != true ? true : try(lower(replace(var.dr_location, " ", "")) != "usgovtexas", false)
    error_message = "US Gov Texas currently does not support geo-redundant backup for PostgreSQL Flexible Server."
  }
}

check "primary_create_required_inputs" {
  assert {
    condition = (
      !var.create_primary_server || (
        var.primary_server_name != null &&
        var.primary_resource_group_name != null &&
        var.networking_mode != null &&
        (var.primary_create_mode != "Default" || (var.postgresql_version != null && var.sku_name != null && var.authentication != null))
      )
    )
    error_message = "Creating a primary requires primary_server_name, primary_resource_group_name, networking_mode; Default mode also requires postgresql_version, sku_name, and authentication."
  }
}

check "primary_restore_inputs" {
  assert {
    condition = (
      !var.create_primary_server || !contains(["PointInTimeRestore", "GeoRestore"], var.primary_create_mode) || (
        var.primary_source_server_id != null && var.primary_point_in_time_restore_time_in_utc != null
      )
    )
    error_message = "PointInTimeRestore and GeoRestore require primary_source_server_id and primary_point_in_time_restore_time_in_utc."
  }
}

check "primary_replica_source" {
  assert {
    condition     = !var.create_primary_server || var.primary_create_mode != "Replica" || var.primary_source_server_id != null
    error_message = "primary_create_mode=Replica requires primary_source_server_id."
  }
}

check "password_auth_inputs" {
  assert {
    condition = try(
      !var.create_primary_server || var.primary_create_mode != "Default" || !var.authentication.password_auth_enabled || (
        var.administrator_login != null && var.administrator_password != null
      ),
      true
    )
    error_message = "When password auth is enabled, provide administrator_login and administrator_password."
  }
}

check "password_disabled_inputs" {
  assert {
    condition = try(
      !var.create_primary_server || var.primary_create_mode != "Default" || var.authentication.password_auth_enabled || (
        var.administrator_login == null && var.administrator_password == null
      ),
      true
    )
    error_message = "Do not provide administrator_login/password when authentication.password_auth_enabled=false."
  }
}

check "entra_auth_tenant" {
  assert {
    condition = try(
      !var.authentication.active_directory_auth_enabled || try(var.authentication.tenant_id, null) != null || var.tenant_id != null,
      true
    )
    error_message = "Entra authentication requires tenant_id either inside authentication or as tenant_id."
  }
}

check "dr_create_required_inputs" {
  assert {
    condition = (
      !var.create_dr_replica || (
        var.dr_server_name != null && var.dr_resource_group_name != null && var.dr_networking_mode != null &&
        (var.create_primary_server || var.existing_primary_server_id != null)
      )
    )
    error_message = "Creating a DR replica requires dr_server_name, dr_resource_group_name, dr_networking_mode, and an effective primary server."
  }
}

check "network_create_inputs" {
  assert {
    condition = (
      (!var.create_primary_networking || (
        var.primary_resource_group_name != null && var.primary_vnet_name != null && length(var.primary_vnet_address_space) > 0 &&
        (var.networking_mode != "private_endpoint" || (var.primary_private_endpoint_subnet_name != null && length(var.primary_private_endpoint_subnet_prefixes) > 0)) &&
        (var.networking_mode != "vnet_integration" || (var.primary_delegated_subnet_name != null && length(var.primary_delegated_subnet_prefixes) > 0))
        )) && (!var.create_dr_networking || (
        var.dr_resource_group_name != null && var.dr_vnet_name != null && length(var.dr_vnet_address_space) > 0 &&
        (var.dr_networking_mode != "private_endpoint" || (var.dr_private_endpoint_subnet_name != null && length(var.dr_private_endpoint_subnet_prefixes) > 0)) &&
        (var.dr_networking_mode != "vnet_integration" || (var.dr_delegated_subnet_name != null && length(var.dr_delegated_subnet_prefixes) > 0))
      ))
    )
    error_message = "Creating networking requires RG/VNet/address space and the subnet details required by the selected networking mode."
  }
}

check "vnet_integration_inputs" {
  assert {
    condition = (
      (!var.create_primary_server || var.networking_mode != "vnet_integration" || (
        (var.create_primary_networking || var.primary_delegated_subnet_id != null) &&
        (var.create_vnet_integration_private_dns_zone || var.existing_vnet_integration_private_dns_zone_id != null)
        )) && (!(var.create_dr_replica || var.create_secondary_server) || var.dr_networking_mode != "vnet_integration" || (
        (var.create_dr_networking || var.dr_delegated_subnet_id != null) &&
        (var.create_vnet_integration_private_dns_zone || var.existing_vnet_integration_private_dns_zone_id != null)
      ))
    )
    error_message = "VNet integration requires an effective delegated subnet and a separate VNet-integration Private DNS zone ending in .postgres.database.azure.com."
  }
}

check "private_dns_create_inputs" {
  assert {
    condition     = !var.create_private_dns_zone || (var.private_dns_zone_name != null && var.private_dns_zone_resource_group_name != null)
    error_message = "Creating Private DNS requires private_dns_zone_name and private_dns_zone_resource_group_name."
  }
}

check "vnet_integration_dns_inputs" {
  assert {
    condition = (
      !var.create_vnet_integration_private_dns_zone || (
        var.vnet_integration_private_dns_zone_name != null &&
        var.vnet_integration_private_dns_zone_resource_group_name != null &&
        try(endswith(var.vnet_integration_private_dns_zone_name, ".postgres.database.azure.com"), false)
      )
    )
    error_message = "Creating the VNet-integration DNS zone requires a name ending in .postgres.database.azure.com and a resource group."
  }
}

check "vnet_integration_dns_create_existing_conflict" {
  assert {
    condition     = !(var.create_vnet_integration_private_dns_zone && var.existing_vnet_integration_private_dns_zone_id != null)
    error_message = "Choose CREATE NEW or USE EXISTING for the VNet-integration DNS zone, not both."
  }
}

check "private_endpoint_inputs" {
  assert {
    condition = (
      (!var.create_primary_private_endpoint || (
        (var.create_primary_server || var.existing_primary_server_id != null) &&
        (var.create_primary_networking || var.primary_private_endpoint_subnet_id != null) &&
        var.primary_private_endpoint_name != null
        )) && (!var.create_dr_private_endpoint || (
        (var.create_dr_replica || var.create_secondary_server || var.existing_dr_server_id != null) &&
        (var.create_dr_networking || var.dr_private_endpoint_subnet_id != null) &&
        var.dr_private_endpoint_name != null
      ))
    )
    error_message = "Creating a Private Endpoint requires an effective server, an effective PE subnet, and an endpoint name."
  }
}

check "private_endpoint_dns_inputs" {
  assert {
    condition     = !var.private_endpoint_attach_dns_zone || var.create_private_dns_zone || var.existing_private_dns_zone_id != null
    error_message = "private_endpoint_attach_dns_zone=true requires a created or existing Private DNS zone."
  }
}

check "identity_create_inputs" {
  assert {
    condition = (
      (!var.create_primary_user_assigned_identity || (var.primary_user_assigned_identity_name != null && var.primary_resource_group_name != null)) &&
      (!var.create_dr_user_assigned_identity || (var.dr_user_assigned_identity_name != null && var.dr_resource_group_name != null))
    )
    error_message = "Creating a UAMI requires its name and regional resource group name."
  }
}

check "identity_create_existing_conflict" {
  assert {
    condition = (
      !(var.create_primary_user_assigned_identity && var.existing_primary_user_assigned_identity_id != null) &&
      !(var.create_dr_user_assigned_identity && var.existing_dr_user_assigned_identity_id != null)
    )
    error_message = "Choose CREATE or USE EXISTING for each UAMI, not both."
  }
}

check "cmk_identity_inputs" {
  assert {
    condition = (
      (var.primary_customer_managed_key == null || try(var.primary_customer_managed_key.primary_user_assigned_identity_id, null) != null || var.existing_primary_user_assigned_identity_id != null || var.create_primary_user_assigned_identity) &&
      (var.dr_customer_managed_key == null || try(var.dr_customer_managed_key.primary_user_assigned_identity_id, null) != null || var.existing_dr_user_assigned_identity_id != null || var.create_dr_user_assigned_identity)
    )
    error_message = "CMK requires a primary user-assigned identity, either explicitly in the CMK block or through the create/existing UAMI inputs."
  }
}

check "elastic_cluster_replica_limits" {
  assert {
    condition = (
      var.deployment_type != "elastic_cluster" || (
        length(var.additional_read_replicas) == 0 &&
        (!var.create_dr_replica || var.dr_networking_mode != "vnet_integration")
      )
    )
    error_message = "Elastic Cluster supports at most the single module DR replica path and does not support VNet injection; use Private Endpoint or public networking for an Elastic Cluster replica."
  }
}

check "direct_read_replica_limit" {
  assert {
    condition     = length(var.additional_read_replicas) + (var.create_dr_replica ? 1 : 0) <= 5
    error_message = "Azure PostgreSQL Flexible Server supports at most 5 direct read replicas per source. additional_read_replicas plus create_dr_replica must not exceed 5."
  }
}

check "primary_feature_target" {
  assert {
    condition = (
      (length(var.database_definitions) == 0 && length(var.server_parameters) == 0 && length(var.primary_server_parameter_overrides) == 0 && length(var.extensions) == 0 && var.pgbouncer_enabled == null && var.query_store == null && var.autonomous_tuning == null && var.logging == null && length(var.entra_administrators) == 0 && var.primary_server_lock_level == null && !var.enable_primary_diagnostics && var.primary_defender_threat_protection_state == null && !var.create_ltr_backup_instance) ||
      var.create_primary_server || var.existing_primary_server_id != null
    )
    error_message = "Primary child features were provided but no primary server is being created or referenced."
  }
}

check "dr_feature_target" {
  assert {
    condition = (
      (!var.manage_entra_administrators_on_dr && !var.apply_server_parameters_to_dr && length(var.dr_server_parameter_overrides) == 0 && var.dr_server_lock_level == null && !var.enable_dr_diagnostics && var.dr_defender_threat_protection_state == null) ||
      var.create_dr_replica || var.create_secondary_server || var.existing_dr_server_id != null
    )
    error_message = "DR child features were provided but no DR server is being created or referenced."
  }
}

check "secondary_database_target" {
  assert {
    condition     = length(var.secondary_database_definitions) == 0 || var.create_secondary_server
    error_message = "secondary_database_definitions is only for a standalone secondary. Do not create databases directly on an Active/Passive read replica."
  }
}

check "virtual_endpoint_pair" {
  assert {
    condition = (
      length(var.virtual_endpoints) == 0 || (
        contains([for ep in values(var.virtual_endpoints) : ep.type], "ReadWrite") &&
        contains([for ep in values(var.virtual_endpoints) : ep.type], "ReadOnly")
      )
    )
    error_message = "For Active/Passive SwitchOver, configure both a ReadWrite and a ReadOnly virtual endpoint."
  }
}

check "switchover_server_symmetry" {
  assert {
    condition = (
      length(var.virtual_endpoints) == 0 || !var.create_dr_replica || (
        (var.dr_sku_name == null || var.sku_name == null || var.dr_sku_name == var.sku_name) &&
        (var.dr_storage_mb == null || var.storage_mb == null || var.dr_storage_mb == var.storage_mb)
      )
    )
    error_message = "Planned SwitchOver with virtual endpoints requires primary/replica tier and storage symmetry. Leave DR overrides null to inherit or make them equal to primary."
  }
}

check "active_passive_virtual_endpoints" {
  assert {
    condition     = length(var.virtual_endpoints) == 0 || var.create_dr_replica || var.existing_dr_server_id != null
    error_message = "Virtual endpoints for DR are intended for an Active/Passive replication topology, not two independent standalone servers."
  }
}

check "virtual_endpoint_targets" {
  assert {
    condition     = length(var.virtual_endpoints) == 0 || ((var.create_primary_server || var.existing_primary_server_id != null) && (var.create_dr_replica || var.create_secondary_server || var.existing_dr_server_id != null))
    error_message = "virtual_endpoints requires effective primary and DR servers."
  }
}

check "diagnostic_destination" {
  assert {
    condition = (
      (!var.enable_primary_diagnostics && !var.enable_dr_diagnostics) ||
      var.create_log_analytics_workspace || var.existing_log_analytics_workspace_id != null || var.diagnostic_storage_account_id != null || var.diagnostic_eventhub_authorization_rule_id != null
    )
    error_message = "Diagnostics require at least one destination: created/existing Log Analytics, Storage Account, or Event Hub authorization rule."
  }
}

check "log_analytics_create_inputs" {
  assert {
    condition = (
      !var.create_log_analytics_workspace || (
        var.log_analytics_workspace_name != null && var.log_analytics_resource_group_name != null && var.log_analytics_location != null
      )
    )
    error_message = "Creating Log Analytics requires name, resource group, and location."
  }
}


check "entra_admin_tenant_inputs" {
  assert {
    condition     = length(var.entra_administrators) == 0 || var.tenant_id != null || alltrue([for admin in values(var.entra_administrators) : try(admin.tenant_id, null) != null])
    error_message = "Each Entra administrator requires tenant_id either globally or in the administrator object."
  }
}

check "firewall_target_inputs" {
  assert {
    condition = (
      alltrue([for rule in values(var.firewall_rules) :
        rule.target == "primary" ? (var.create_primary_server || var.existing_primary_server_id != null) : (var.create_dr_replica || var.create_secondary_server || var.existing_dr_server_id != null)
      ])
    )
    error_message = "Each firewall rule must target an effective primary or DR server."
  }
}

check "backup_target_inputs" {
  assert {
    condition = (
      alltrue([for backup in values(var.on_demand_backups) :
        backup.target == "primary" ? (var.create_primary_server || var.existing_primary_server_id != null) : ((var.create_secondary_server || var.existing_dr_server_id != null) && !var.create_dr_replica)
      ])
    )
    error_message = "On-demand backup can target the primary or a standalone/existing secondary. A module-created read replica cannot be a backup target."
  }
}

check "metric_alert_target_inputs" {
  assert {
    condition = (
      alltrue([for alert in values(var.metric_alerts) :
        alert.target == "primary" ? (var.create_primary_server || var.existing_primary_server_id != null) : (var.create_dr_replica || var.create_secondary_server || var.existing_dr_server_id != null)
      ])
    )
    error_message = "Each metric alert must target an effective primary or DR server."
  }
}

check "private_dns_link_inputs" {
  assert {
    condition = (
      length(var.private_dns_vnet_links) == 0 || (
        var.create_private_dns_zone || var.existing_private_dns_zone_id != null
      )
    )
    error_message = "private_dns_vnet_links requires a created or existing Private DNS zone."
  }
}

check "private_dns_link_vnet_alias_inputs" {
  assert {
    condition = (
      alltrue([for link in values(var.private_dns_vnet_links) :
        link.vnet_id == "primary" ? (var.create_primary_networking || var.primary_vnet_id != null) :
        link.vnet_id == "dr" ? (var.create_dr_networking || var.dr_vnet_id != null) : startswith(link.vnet_id, "/subscriptions/")
      ])
    )
    error_message = "Each DNS link must use primary/dr with an effective VNet, or a full VNet resource ID."
  }
}


check "creation_only_server_feature_inputs" {
  assert {
    condition = (
      (
        # Primary-only server properties require a module-created primary.
        (var.create_primary_server || (
          var.primary_high_availability == null && var.maintenance_window == null &&
          var.primary_customer_managed_key == null && !var.primary_system_assigned_identity_enabled
        )) &&
        # Standalone-secondary-only properties require a module-created standalone secondary.
        (var.create_secondary_server || (
          var.dr_customer_managed_key == null && !var.dr_system_assigned_identity_enabled &&
          var.dr_high_availability == null && var.dr_maintenance_window == null
        )) &&
        # Authentication and Elastic Cluster are shared creation-time properties and are valid
        # when at least one standalone writable server is being created. A read replica inherits
        # these characteristics from its source and does not accept them independently.
        ((var.create_primary_server || var.create_secondary_server) || (
          var.authentication == null && var.elastic_cluster == null
        ))
      )
    )
    error_message = "Creation-time server properties can be configured only on servers this module creates. Primary HA/maintenance/CMK/system identity require create_primary_server=true; secondary HA/maintenance/CMK/system identity require create_secondary_server=true; authentication/Elastic Cluster require a created primary or standalone secondary. Existing servers must be imported before these properties can be managed declaratively."
  }
}

check "deployment_type_inputs" {
  assert {
    condition = (
      var.deployment_type == "server" ? var.elastic_cluster == null : (
        (!(var.create_primary_server || var.create_secondary_server) || (var.elastic_cluster != null && var.primary_create_mode == "Default" && var.postgresql_version == "17")) &&
        length(var.database_definitions) == 0 &&
        length(var.secondary_database_definitions) == 0 &&
        try(!var.query_store.enabled, true) &&
        try(!var.autonomous_tuning.enabled, true) &&
        var.auto_grow_enabled != true &&
        var.networking_mode != "vnet_integration" &&
        length(var.additional_read_replicas) == 0 &&
        length(setintersection(var.extensions, toset(["anon", "pg_qs", "postgis_topology", "timescaledb", "TimescaleDB"]))) == 0
      )
    )
    error_message = "deployment_type=server requires elastic_cluster=null. Elastic Cluster requires PostgreSQL 17/Default when created, uses its single default database, does not support Query Store/Autonomous Tuning/storage autoscale/VNet injection/additional replicas, and blocks known unsupported extensions. One DR read replica can be enabled via create_dr_replica."
  }
}

check "autonomous_tuning_inputs" {
  assert {
    condition = try(
      !var.autonomous_tuning.enabled || (
        local.primary_server_present &&
        var.deployment_type == "server" &&
        try(!startswith(var.sku_name, "B_"), true) &&
        try(var.query_store.enabled, false)
      ),
      true
    )
    error_message = "Autonomous Tuning requires an effective standard Flexible Server and must not use Burstable compute or Elastic Cluster."
  }
}

check "defender_target_inputs" {
  assert {
    condition = (
      (var.primary_defender_threat_protection_state == null || local.primary_server_present) &&
      (var.dr_defender_threat_protection_state == null || local.dr_server_present)
    )
    error_message = "Resource-level Defender state was provided for a PostgreSQL target that is neither created nor referenced."
  }
}

check "backup_vault_inputs" {
  assert {
    condition = (
      !(var.create_backup_vault && var.existing_backup_vault_id != null) &&
      (!var.create_backup_vault || (
        var.backup_vault_name != null && var.backup_vault_resource_group_name != null && var.backup_vault_location != null && var.backup_vault_redundancy != null
      )) &&
      !(var.backup_vault_cross_region_restore_enabled == true && var.backup_vault_redundancy != "GeoRedundant")
    )
    error_message = "Choose CREATE or USE EXISTING for Backup Vault. Creating it requires name/RG/location/redundancy; cross-region restore requires GeoRedundant."
  }
}

check "backup_policy_inputs" {
  assert {
    condition = (
      !(var.create_backup_policy && var.existing_backup_policy_id != null) &&
      (!var.create_backup_policy || (
        (var.create_backup_vault || var.existing_backup_vault_id != null) &&
        var.backup_policy_name != null && length(var.backup_repeating_time_intervals) > 0 && var.backup_policy_default_retention_duration != null
      ))
    )
    error_message = "Creating an LTR backup policy requires an effective Backup Vault, policy name, weekly repeating interval(s), and default retention duration."
  }
}

check "ltr_backup_instance_inputs" {
  assert {
    condition = (
      !(var.create_ltr_backup_instance && var.existing_ltr_backup_instance_id != null) &&
      (!var.create_ltr_backup_instance || (
        local.primary_server_present &&
        (var.create_backup_vault || var.existing_backup_vault_id != null) &&
        (var.create_backup_policy || var.existing_backup_policy_id != null) &&
        var.ltr_backup_instance_name != null
      )) &&
      (!var.manage_ltr_role_assignments || var.create_backup_vault || var.existing_backup_vault_principal_id != null)
    )
    error_message = "Creating PostgreSQL LTR protection requires an effective primary, Backup Vault, Backup Policy and instance name. Existing vault role management also requires existing_backup_vault_principal_id."
  }
}

check "action_group_inputs" {
  assert {
    condition = (
      !(var.create_monitor_action_group && var.existing_monitor_action_group_id != null) &&
      (!var.create_monitor_action_group || (
        var.monitor_action_group_name != null && var.monitor_action_group_resource_group_name != null && var.monitor_action_group_short_name != null
      )) &&
      alltrue([for alert in values(var.metric_alerts) : !alert.use_default_action_group || var.create_monitor_action_group || var.existing_monitor_action_group_id != null])
    )
    error_message = "Creating an Action Group requires name/RG/short name; metric alerts using the default Action Group require a created or existing Action Group."
  }
}

check "workbook_inputs" {
  assert {
    condition = (
      !(var.create_monitor_workbook && var.existing_monitor_workbook_id != null) &&
      (!var.create_monitor_workbook || (
        var.monitor_workbook_name != null && var.monitor_workbook_resource_group_name != null && var.monitor_workbook_location != null &&
        var.monitor_workbook_display_name != null && var.monitor_workbook_data_json != null
      ))
    )
    error_message = "Creating a Workbook requires a lowercase GUID name, resource group, location, display name, and data_json."
  }
}

check "primary_key_vault_inputs" {
  assert {
    condition = (
      !(var.create_primary_key_vault && var.existing_primary_key_vault_id != null) &&
      (!var.create_primary_key_vault || (
        var.primary_key_vault_name != null &&
        var.primary_key_vault_resource_group_name != null &&
        var.primary_key_vault_location != null
      )) &&
      !(var.create_primary_key_vault_key && var.existing_primary_key_vault_key_id != null) &&
      (!var.create_primary_key_vault_key || (
        (var.create_primary_key_vault || var.existing_primary_key_vault_id != null) &&
        var.primary_key_vault_key_name != null
      ))
    )
    error_message = "Choose CREATE or USE EXISTING for the primary Key Vault/key. Creating the vault requires name/RG/location; creating the key requires an effective primary vault and key name."
  }
}

check "dr_key_vault_inputs" {
  assert {
    condition = (
      !(var.create_dr_key_vault && var.existing_dr_key_vault_id != null) &&
      (!var.create_dr_key_vault || (
        var.dr_key_vault_name != null &&
        var.dr_key_vault_resource_group_name != null &&
        var.dr_key_vault_location != null
      )) &&
      !(var.create_dr_key_vault_key && var.existing_dr_key_vault_key_id != null) &&
      (!var.create_dr_key_vault_key || (
        (var.create_dr_key_vault || var.existing_dr_key_vault_id != null) &&
        var.dr_key_vault_key_name != null
      ))
    )
    error_message = "Choose CREATE or USE EXISTING for the DR Key Vault/key. Creating the vault requires name/RG/location; creating the key requires an effective DR vault and key name."
  }
}

check "regional_key_vault_private_dns_inputs" {
  assert {
    condition = (
      !(var.create_primary_key_vault_private_dns_zone && var.existing_primary_key_vault_private_dns_zone_id != null) &&
      (!var.create_primary_key_vault_private_dns_zone || (
        var.primary_key_vault_private_dns_zone_name != null &&
        var.primary_key_vault_private_dns_zone_resource_group_name != null
      )) &&
      !(var.create_dr_key_vault_private_dns_zone && var.existing_dr_key_vault_private_dns_zone_id != null) &&
      (!var.create_dr_key_vault_private_dns_zone || (
        var.dr_key_vault_private_dns_zone_name != null &&
        var.dr_key_vault_private_dns_zone_resource_group_name != null
      ))
    )
    error_message = "Choose CREATE or USE EXISTING independently for primary and DR Key Vault Private DNS zones. Creating a zone requires name and resource group."
  }
}

check "regional_key_vault_private_dns_vnet_link_inputs" {
  assert {
    condition = (
      !var.create_primary_key_vault_private_dns_vnet_link || (
        (var.create_primary_key_vault_private_dns_zone || var.existing_primary_key_vault_private_dns_zone_id != null) &&
        var.primary_key_vault_private_dns_vnet_link_name != null &&
        (var.create_primary_networking || var.primary_vnet_id != null)
      )
      ) && (
      !var.create_dr_key_vault_private_dns_vnet_link || (
        (var.create_dr_key_vault_private_dns_zone || var.existing_dr_key_vault_private_dns_zone_id != null) &&
        var.dr_key_vault_private_dns_vnet_link_name != null &&
        (var.create_dr_networking || var.dr_vnet_id != null)
      )
    )
    error_message = "Each regional Key Vault DNS VNet link requires its effective regional DNS zone, link name, and effective regional VNet."
  }
}

check "regional_key_vault_private_endpoint_inputs" {
  assert {
    condition = (
      !(var.create_primary_key_vault_private_endpoint && var.existing_primary_key_vault_private_endpoint_id != null) &&
      (!var.create_primary_key_vault_private_endpoint || (
        (var.create_primary_key_vault || var.existing_primary_key_vault_id != null) &&
        var.primary_key_vault_private_endpoint_name != null &&
        var.primary_key_vault_location != null &&
        var.primary_key_vault_resource_group_name != null &&
        (
          var.primary_key_vault_private_endpoint_subnet_id != null ||
          (var.networking_mode == "private_endpoint" && (var.create_primary_networking || var.primary_private_endpoint_subnet_id != null))
        )
      ))
      ) && (
      !(var.create_dr_key_vault_private_endpoint && var.existing_dr_key_vault_private_endpoint_id != null) &&
      (!var.create_dr_key_vault_private_endpoint || (
        (var.create_dr_key_vault || var.existing_dr_key_vault_id != null) &&
        var.dr_key_vault_private_endpoint_name != null &&
        var.dr_key_vault_location != null &&
        var.dr_key_vault_resource_group_name != null &&
        (
          var.dr_key_vault_private_endpoint_subnet_id != null ||
          (var.dr_networking_mode == "private_endpoint" && (var.create_dr_networking || var.dr_private_endpoint_subnet_id != null))
        )
      ))
    )
    error_message = "Each regional Key Vault Private Endpoint requires its effective Key Vault, PE name/location/RG, and an explicit or effective regional PE subnet."
  }
}

check "cmk_private_key_vault_security" {
  assert {
    condition = (
      !var.create_primary_key_vault || (
        var.primary_key_vault_rbac_authorization_enabled == true &&
        var.primary_key_vault_purge_protection_enabled == true &&
        var.primary_key_vault_public_network_access_enabled != true &&
        var.primary_key_vault_network_acls.default_action == "Deny"
      )
      ) && (
      !var.create_dr_key_vault || (
        var.dr_key_vault_rbac_authorization_enabled == true &&
        var.dr_key_vault_purge_protection_enabled == true &&
        var.dr_key_vault_public_network_access_enabled != true &&
        var.dr_key_vault_network_acls.default_action == "Deny"
      )
    )
    error_message = "Module-created primary and DR CMK Key Vaults must use RBAC, purge protection, public access disabled, and network_acls.default_action=Deny."
  }
}

check "cmk_key_inputs" {
  assert {
    condition = (
      var.primary_customer_managed_key == null ||
      try(var.primary_customer_managed_key.key_vault_key_id, null) != null ||
      var.create_primary_key_vault_key ||
      var.existing_primary_key_vault_key_id != null
      ) && (
      var.dr_customer_managed_key == null ||
      try(var.dr_customer_managed_key.key_vault_key_id, null) != null ||
      var.create_dr_key_vault_key ||
      var.existing_dr_key_vault_key_id != null
    )
    error_message = "Primary CMK requires a primary regional key; DR CMK requires a DR regional key. Supply an explicit key_vault_key_id in the CMK block or create/reference the matching regional Key Vault key."
  }
}

check "regional_cmk_role_assignment_inputs" {
  assert {
    condition = (
      !(var.create_cmk_role_assignments || var.create_primary_cmk_role_assignment) ||
      var.primary_customer_managed_key == null || (
        (var.create_primary_key_vault || var.existing_primary_key_vault_id != null) &&
        (var.create_primary_user_assigned_identity || var.existing_primary_user_assigned_identity_id != null)
      )
      ) && (
      !(var.create_cmk_role_assignments || var.create_dr_cmk_role_assignment) ||
      var.dr_customer_managed_key == null || (
        (var.create_dr_key_vault || var.existing_dr_key_vault_id != null) &&
        (var.create_dr_user_assigned_identity || var.existing_dr_user_assigned_identity_id != null)
      )
    )
    error_message = "A requested regional CMK RBAC assignment requires the matching regional Key Vault and the matching effective PostgreSQL UAMI. If RBAC is externally managed, leave the regional CMK role-assignment switch false."
  }
}

check "regional_private_cmk_data_plane_inputs" {
  assert {
    condition = (
      !(var.create_primary_key_vault && var.create_primary_key_vault_key) || (
        var.create_primary_key_vault_private_endpoint &&
        (
          var.existing_primary_key_vault_private_dns_zone_id != null ||
          (
            var.create_primary_key_vault_private_dns_zone &&
            var.create_primary_key_vault_private_dns_vnet_link
          )
        )
      )
      ) && (
      !(var.create_dr_key_vault && var.create_dr_key_vault_key) || (
        var.create_dr_key_vault_private_endpoint &&
        (
          var.existing_dr_key_vault_private_dns_zone_id != null ||
          (
            var.create_dr_key_vault_private_dns_zone &&
            var.create_dr_key_vault_private_dns_vnet_link
          )
        )
      )
    )

    error_message = "When this module creates a private-only regional Key Vault and its key, the region requires a Key Vault Private Endpoint and either an existing Private DNS zone with externally managed VNet connectivity or a module-created Private DNS zone and VNet link."
  }
}

check "regional_cmk_separation" {
  assert {
    condition = (
      local.primary_cmk_key_id == null || local.dr_cmk_key_id == null
      ? true
      : lower(local.primary_cmk_key_id) != lower(local.dr_cmk_key_id)
    )

    error_message = "Enterprise cross-region CMK requires different effective primary and DR Key Vault key IDs."
  }
}

check "role_assignment_scope_alias_inputs" {
  assert {
    condition = (
      alltrue([for assignment in values(var.role_assignments) :
        assignment.scope == "primary_server" ? (var.create_primary_server || var.existing_primary_server_id != null) :
        assignment.scope == "dr_server" ? (var.create_dr_replica || var.create_secondary_server || var.existing_dr_server_id != null) :
        assignment.scope == "private_dns_zone" ? (var.create_private_dns_zone || var.existing_private_dns_zone_id != null) :
        assignment.scope == "log_analytics" ? (var.create_log_analytics_workspace || var.existing_log_analytics_workspace_id != null) :
        assignment.scope == "primary_key_vault" ? (var.create_primary_key_vault || var.existing_primary_key_vault_id != null) :
        assignment.scope == "dr_key_vault" ? (var.create_dr_key_vault || var.existing_dr_key_vault_id != null) :
        assignment.scope == "backup_vault" ? (var.create_backup_vault || var.existing_backup_vault_id != null) :
        assignment.scope == "action_group" ? (var.create_monitor_action_group || var.existing_monitor_action_group_id != null) : startswith(assignment.scope, "/subscriptions/")
      ])
    )
    error_message = "role_assignments.scope aliases require the corresponding effective resource; otherwise supply a full Azure resource ID."
  }
}
