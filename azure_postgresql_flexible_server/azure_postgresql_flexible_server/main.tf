data "azurerm_client_config" "current" {}

locals {
  primary_server_present = var.create_primary_server || var.existing_primary_server_id != null
  dr_server_present      = var.create_dr_replica || var.create_secondary_server || var.existing_dr_server_id != null

  existing_primary_parts = var.existing_primary_server_id == null ? [] : split("/", var.existing_primary_server_id)
  existing_dr_parts      = var.existing_dr_server_id == null ? [] : split("/", var.existing_dr_server_id)

  existing_primary_rg   = var.existing_primary_server_id == null ? null : try(local.existing_primary_parts[4], null)
  existing_primary_name = var.existing_primary_server_id == null ? null : try(local.existing_primary_parts[8], null)
  existing_dr_rg        = var.existing_dr_server_id == null ? null : try(local.existing_dr_parts[4], null)
  existing_dr_name      = var.existing_dr_server_id == null ? null : try(local.existing_dr_parts[8], null)

  primary_vnet_id = var.create_primary_networking ? azurerm_virtual_network.primary[0].id : var.primary_vnet_id
  dr_vnet_id      = var.create_dr_networking ? azurerm_virtual_network.dr[0].id : var.dr_vnet_id

  primary_private_endpoint_subnet_id = var.create_primary_networking && var.networking_mode == "private_endpoint" ? azurerm_subnet.primary_private_endpoint[0].id : var.primary_private_endpoint_subnet_id
  dr_private_endpoint_subnet_id      = var.create_dr_networking && var.dr_networking_mode == "private_endpoint" ? azurerm_subnet.dr_private_endpoint[0].id : var.dr_private_endpoint_subnet_id
  primary_delegated_subnet_id        = var.create_primary_networking && var.networking_mode == "vnet_integration" ? azurerm_subnet.primary_delegated[0].id : var.primary_delegated_subnet_id
  dr_delegated_subnet_id             = var.create_dr_networking && var.dr_networking_mode == "vnet_integration" ? azurerm_subnet.dr_delegated[0].id : var.dr_delegated_subnet_id

  private_dns_zone_id                  = var.create_private_dns_zone ? azurerm_private_dns_zone.postgresql[0].id : var.existing_private_dns_zone_id
  vnet_integration_private_dns_zone_id = var.create_vnet_integration_private_dns_zone ? azurerm_private_dns_zone.postgresql_vnet_integration[0].id : var.existing_vnet_integration_private_dns_zone_id

  primary_uami_id             = var.create_primary_user_assigned_identity ? azurerm_user_assigned_identity.primary[0].id : var.existing_primary_user_assigned_identity_id
  dr_uami_id                  = var.create_dr_user_assigned_identity ? azurerm_user_assigned_identity.dr[0].id : var.existing_dr_user_assigned_identity_id
  existing_primary_uami_parts = var.existing_primary_user_assigned_identity_id == null ? [] : split("/", var.existing_primary_user_assigned_identity_id)
  existing_dr_uami_parts      = var.existing_dr_user_assigned_identity_id == null ? [] : split("/", var.existing_dr_user_assigned_identity_id)

  existing_primary_uami_rg   = var.existing_primary_user_assigned_identity_id == null ? null : try(local.existing_primary_uami_parts[4], null)
  existing_primary_uami_name = var.existing_primary_user_assigned_identity_id == null ? null : try(local.existing_primary_uami_parts[8], null)

  existing_dr_uami_rg   = var.existing_dr_user_assigned_identity_id == null ? null : try(local.existing_dr_uami_parts[4], null)
  existing_dr_uami_name = var.existing_dr_user_assigned_identity_id == null ? null : try(local.existing_dr_uami_parts[8], null)
  primary_uami_principal_id = var.create_primary_user_assigned_identity ? (
    azurerm_user_assigned_identity.primary[0].principal_id
    ) : (
    var.existing_primary_user_assigned_identity_id != null ?
    data.azurerm_user_assigned_identity.primary_existing[0].principal_id :
    null
  )

  dr_uami_principal_id = var.create_dr_user_assigned_identity ? (
    azurerm_user_assigned_identity.dr[0].principal_id
    ) : (
    var.existing_dr_user_assigned_identity_id != null ?
    data.azurerm_user_assigned_identity.dr_existing[0].principal_id :
    null
  )
  primary_cmk_primary_uami_id = var.primary_customer_managed_key == null ? null : (
    try(var.primary_customer_managed_key.primary_user_assigned_identity_id, null) != null ?
    var.primary_customer_managed_key.primary_user_assigned_identity_id : local.primary_uami_id
  )
  dr_cmk_primary_uami_id = var.dr_customer_managed_key == null ? null : (
    try(var.dr_customer_managed_key.primary_user_assigned_identity_id, null) != null ?
    var.dr_customer_managed_key.primary_user_assigned_identity_id : local.dr_uami_id
  )

  primary_identity_ids = distinct(compact([
    local.primary_uami_id,
    local.primary_cmk_primary_uami_id,
    var.primary_customer_managed_key == null ? null : try(var.primary_customer_managed_key.geo_backup_user_assigned_identity_id, null)
  ]))
  dr_identity_ids = distinct(compact([
    local.dr_uami_id,
    local.dr_cmk_primary_uami_id,
    var.dr_customer_managed_key == null ? null : try(var.dr_customer_managed_key.geo_backup_user_assigned_identity_id, null)
  ]))

  primary_identity_type = var.primary_system_assigned_identity_enabled ? (
    length(local.primary_identity_ids) > 0 ? "SystemAssigned, UserAssigned" : "SystemAssigned"
  ) : (length(local.primary_identity_ids) > 0 ? "UserAssigned" : null)

  dr_identity_type = var.dr_system_assigned_identity_enabled ? (
    length(local.dr_identity_ids) > 0 ? "SystemAssigned, UserAssigned" : "SystemAssigned"
  ) : (length(local.dr_identity_ids) > 0 ? "UserAssigned" : null)

  base_server_parameters = merge(
    var.server_parameters,
    length(var.extensions) > 0 ? { "azure.extensions" = join(",", sort(tolist(var.extensions))) } : {},
    var.pgbouncer_enabled == null ? {} : { "pgbouncer.enabled" = tostring(var.pgbouncer_enabled) }
  )

  query_store_parameters = var.query_store == null ? {} : (
    var.query_store.enabled ? merge(
      {
        "pg_qs.query_capture_mode"              = lower(var.query_store.query_capture_mode)
        "pgms_wait_sampling.query_capture_mode" = lower(var.query_store.wait_sampling_query_capture_mode)
      },
      try(var.query_store.retention_period_in_days, null) == null ? {} : { "pg_qs.retention_period_in_days" = tostring(var.query_store.retention_period_in_days) },
      try(var.query_store.store_query_plans, null) == null ? {} : { "pg_qs.store_query_plans" = var.query_store.store_query_plans ? "on" : "off" }
      ) : {
      "pg_qs.query_capture_mode"              = "none"
      "pgms_wait_sampling.query_capture_mode" = "none"
    }
  )

  autonomous_tuning_parameters = var.autonomous_tuning == null ? {} : (
    var.autonomous_tuning.enabled ? merge(
      {
        "index_tuning.mode"              = "report"
        "index_tuning.analysis_interval" = tostring(try(var.autonomous_tuning.analysis_interval, 720))
        # Autonomous tuning requires Query Store. If query_store is omitted, enable full capture.
        "pg_qs.query_capture_mode" = var.query_store == null ? "all" : lower(var.query_store.query_capture_mode)
      },
      try(var.autonomous_tuning.max_columns_per_index, null) == null ? {} : { "index_tuning.max_columns_per_index" = tostring(var.autonomous_tuning.max_columns_per_index) },
      try(var.autonomous_tuning.max_index_count, null) == null ? {} : { "index_tuning.max_index_count" = tostring(var.autonomous_tuning.max_index_count) },
      try(var.autonomous_tuning.max_indexes_per_table, null) == null ? {} : { "index_tuning.max_indexes_per_table" = tostring(var.autonomous_tuning.max_indexes_per_table) },
      try(var.autonomous_tuning.min_improvement_factor, null) == null ? {} : { "index_tuning.min_improvement_factor" = tostring(var.autonomous_tuning.min_improvement_factor) }
    ) : { "index_tuning.mode" = "off" }
  )

  logging_parameters = var.logging == null ? {} : merge(
    try(var.logging.log_connections, null) == null ? {} : { "log_connections" = var.logging.log_connections ? "on" : "off" },
    try(var.logging.log_disconnections, null) == null ? {} : { "log_disconnections" = var.logging.log_disconnections ? "on" : "off" },
    try(var.logging.log_checkpoints, null) == null ? {} : { "log_checkpoints" = var.logging.log_checkpoints ? "on" : "off" },
    try(var.logging.log_duration, null) == null ? {} : { "log_duration" = var.logging.log_duration ? "on" : "off" },
    try(var.logging.log_lock_waits, null) == null ? {} : { "log_lock_waits" = var.logging.log_lock_waits ? "on" : "off" },
    try(var.logging.log_min_duration_statement, null) == null ? {} : { "log_min_duration_statement" = tostring(var.logging.log_min_duration_statement) },
    try(var.logging.log_autovacuum_min_duration, null) == null ? {} : { "log_autovacuum_min_duration" = tostring(var.logging.log_autovacuum_min_duration) },
    try(var.logging.log_temp_files, null) == null ? {} : { "log_temp_files" = tostring(var.logging.log_temp_files) },
    try(var.logging.log_statement, null) == null ? {} : { "log_statement" = var.logging.log_statement }
  )

  primary_convenience_parameters = var.deployment_type == "server" ? merge(
    local.query_store_parameters,
    local.autonomous_tuning_parameters,
    local.logging_parameters
  ) : local.logging_parameters

  primary_effective_server_parameters = merge(
    local.base_server_parameters,
    local.primary_convenience_parameters,
    var.primary_server_parameter_overrides
  )
  dr_effective_server_parameters = merge(
    var.apply_server_parameters_to_dr ? local.base_server_parameters : {},
    var.dr_server_parameter_overrides
  )

  log_analytics_workspace_id = var.create_log_analytics_workspace ? azurerm_log_analytics_workspace.postgresql[0].id : var.existing_log_analytics_workspace_id

  primary_key_vault_private_dns_zone_id = (
    var.create_primary_key_vault_private_dns_zone ?
    azurerm_private_dns_zone.primary_key_vault[0].id :
    var.existing_primary_key_vault_private_dns_zone_id
  )
  dr_key_vault_private_dns_zone_id = (
    var.create_dr_key_vault_private_dns_zone ?
    azurerm_private_dns_zone.dr_key_vault[0].id :
    var.existing_dr_key_vault_private_dns_zone_id
  )

  primary_key_vault_private_endpoint_id = (
    var.create_primary_key_vault_private_endpoint ?
    azurerm_private_endpoint.primary_key_vault[0].id :
    var.existing_primary_key_vault_private_endpoint_id
  )
  dr_key_vault_private_endpoint_id = (
    var.create_dr_key_vault_private_endpoint ?
    azurerm_private_endpoint.dr_key_vault[0].id :
    var.existing_dr_key_vault_private_endpoint_id
  )

  primary_key_vault_id = var.create_primary_key_vault ? azurerm_key_vault.primary_postgresql[0].id : var.existing_primary_key_vault_id
  dr_key_vault_id      = var.create_dr_key_vault ? azurerm_key_vault.dr_postgresql[0].id : var.existing_dr_key_vault_id

  primary_key_vault_key_id = var.create_primary_key_vault_key ? azurerm_key_vault_key.primary_postgresql[0].versionless_id : var.existing_primary_key_vault_key_id
  dr_key_vault_key_id      = var.create_dr_key_vault_key ? azurerm_key_vault_key.dr_postgresql[0].versionless_id : var.existing_dr_key_vault_key_id

  # Explicit CMK key IDs take precedence. Otherwise each region falls back only
  # to its own regional Key Vault key. try(coalesce(...), null) lets the checks
  # below return a useful validation error instead of failing local evaluation.
  primary_cmk_key_id = var.primary_customer_managed_key == null ? null : try(coalesce(
    try(var.primary_customer_managed_key.key_vault_key_id, null),
    local.primary_key_vault_key_id
  ), null)
  dr_cmk_key_id = var.dr_customer_managed_key == null ? null : try(coalesce(
    try(var.dr_customer_managed_key.key_vault_key_id, null),
    local.dr_key_vault_key_id
  ), null)

  backup_vault_id           = var.create_backup_vault ? azurerm_data_protection_backup_vault.postgresql[0].id : var.existing_backup_vault_id
  backup_vault_principal_id = var.create_backup_vault ? azurerm_data_protection_backup_vault.postgresql[0].identity[0].principal_id : var.existing_backup_vault_principal_id
  backup_policy_id          = var.create_backup_policy ? azurerm_data_protection_backup_policy_postgresql_flexible_server.postgresql[0].id : var.existing_backup_policy_id
  ltr_backup_instance_id    = var.create_ltr_backup_instance ? azurerm_data_protection_backup_instance_postgresql_flexible_server.postgresql[0].id : var.existing_ltr_backup_instance_id

  monitor_action_group_id = var.create_monitor_action_group ? azurerm_monitor_action_group.postgresql[0].id : var.existing_monitor_action_group_id
  monitor_workbook_id     = var.create_monitor_workbook ? azurerm_application_insights_workbook.postgresql[0].id : var.existing_monitor_workbook_id

  role_scope_aliases = {
    primary_server    = local.primary_server_id
    dr_server         = local.dr_server_id
    private_dns_zone  = local.private_dns_zone_id
    log_analytics     = local.log_analytics_workspace_id
    primary_key_vault = local.primary_key_vault_id
    dr_key_vault      = local.dr_key_vault_id
    backup_vault      = local.backup_vault_id
    action_group      = local.monitor_action_group_id
  }

  common_tags = var.tags
}

# =============================================================================
# RESOURCE GROUPS - CREATE NEW / USE EXISTING
# =============================================================================
resource "azurerm_resource_group" "primary" {
  count    = var.create_primary_resource_group ? 1 : 0
  name     = var.primary_resource_group_name
  location = var.primary_location
  tags     = merge(local.common_tags, { Role = "Primary" })
}

resource "azurerm_resource_group" "dr" {
  count    = var.create_dr_resource_group ? 1 : 0
  name     = var.dr_resource_group_name
  location = var.dr_location
  tags     = merge(local.common_tags, { Role = "DR" })
}

# =============================================================================
# NETWORKING - CREATE NEW / USE EXISTING
# =============================================================================
resource "azurerm_virtual_network" "primary" {
  count               = var.create_primary_networking ? 1 : 0
  name                = var.primary_vnet_name
  location            = var.primary_location
  resource_group_name = var.primary_resource_group_name
  address_space       = var.primary_vnet_address_space
  tags                = merge(local.common_tags, { Role = "Primary" })

  depends_on = [azurerm_resource_group.primary]
}

resource "azurerm_subnet" "primary_private_endpoint" {
  count                = var.create_primary_networking && var.networking_mode == "private_endpoint" ? 1 : 0
  name                 = var.primary_private_endpoint_subnet_name
  resource_group_name  = var.primary_resource_group_name
  virtual_network_name = azurerm_virtual_network.primary[0].name
  address_prefixes     = var.primary_private_endpoint_subnet_prefixes
}

resource "azurerm_subnet" "primary_delegated" {
  count                = var.create_primary_networking && var.networking_mode == "vnet_integration" ? 1 : 0
  name                 = var.primary_delegated_subnet_name
  resource_group_name  = var.primary_resource_group_name
  virtual_network_name = azurerm_virtual_network.primary[0].name
  address_prefixes     = var.primary_delegated_subnet_prefixes

  delegation {
    name = "postgresql-flexible-server"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_virtual_network" "dr" {
  count               = var.create_dr_networking ? 1 : 0
  name                = var.dr_vnet_name
  location            = var.dr_location
  resource_group_name = var.dr_resource_group_name
  address_space       = var.dr_vnet_address_space
  tags                = merge(local.common_tags, { Role = "DR" })

  depends_on = [azurerm_resource_group.dr]
}

resource "azurerm_subnet" "dr_private_endpoint" {
  count                = var.create_dr_networking && var.dr_networking_mode == "private_endpoint" ? 1 : 0
  name                 = var.dr_private_endpoint_subnet_name
  resource_group_name  = var.dr_resource_group_name
  virtual_network_name = azurerm_virtual_network.dr[0].name
  address_prefixes     = var.dr_private_endpoint_subnet_prefixes
}

resource "azurerm_subnet" "dr_delegated" {
  count                = var.create_dr_networking && var.dr_networking_mode == "vnet_integration" ? 1 : 0
  name                 = var.dr_delegated_subnet_name
  resource_group_name  = var.dr_resource_group_name
  virtual_network_name = azurerm_virtual_network.dr[0].name
  address_prefixes     = var.dr_delegated_subnet_prefixes

  delegation {
    name = "postgresql-flexible-server"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# =============================================================================
# PRIVATE DNS - CREATE NEW / USE EXISTING
# =============================================================================
resource "azurerm_private_dns_zone" "postgresql" {
  count               = var.create_private_dns_zone ? 1 : 0
  name                = var.private_dns_zone_name
  resource_group_name = var.private_dns_zone_resource_group_name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  for_each = var.private_dns_vnet_links

  name                  = each.value.name
  resource_group_name   = var.create_private_dns_zone ? var.private_dns_zone_resource_group_name : try(split("/", local.private_dns_zone_id)[4], null)
  private_dns_zone_name = var.create_private_dns_zone ? var.private_dns_zone_name : try(split("/", local.private_dns_zone_id)[8], null)
  virtual_network_id = each.value.vnet_id == "primary" ? local.primary_vnet_id : (
    each.value.vnet_id == "dr" ? local.dr_vnet_id : each.value.vnet_id
  )
  registration_enabled = false
  tags                 = local.common_tags
}

resource "azurerm_private_dns_zone" "postgresql_vnet_integration" {
  count               = var.create_vnet_integration_private_dns_zone ? 1 : 0
  name                = var.vnet_integration_private_dns_zone_name
  resource_group_name = var.vnet_integration_private_dns_zone_resource_group_name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgresql_vnet_integration" {
  for_each = var.vnet_integration_dns_vnet_links

  name                  = each.value.name
  resource_group_name   = var.create_vnet_integration_private_dns_zone ? var.vnet_integration_private_dns_zone_resource_group_name : try(split("/", local.vnet_integration_private_dns_zone_id)[4], null)
  private_dns_zone_name = var.create_vnet_integration_private_dns_zone ? var.vnet_integration_private_dns_zone_name : try(split("/", local.vnet_integration_private_dns_zone_id)[8], null)
  virtual_network_id = each.value.vnet_id == "primary" ? local.primary_vnet_id : (
    each.value.vnet_id == "dr" ? local.dr_vnet_id : each.value.vnet_id
  )
  registration_enabled = false
  tags                 = local.common_tags
}
# =============================================================================
# KEY VAULT PRIVATE DNS - PRIMARY / DR CREATE NEW / USE EXISTING
# =============================================================================

resource "azurerm_private_dns_zone" "primary_key_vault" {
  count = var.create_primary_key_vault_private_dns_zone ? 1 : 0

  name                = var.primary_key_vault_private_dns_zone_name
  resource_group_name = var.primary_key_vault_private_dns_zone_resource_group_name

  tags = merge(local.common_tags, { Role = "Primary-CMK-DNS" })
}

resource "azurerm_private_dns_zone_virtual_network_link" "primary_key_vault" {
  count = var.create_primary_key_vault_private_dns_vnet_link ? 1 : 0

  name = var.primary_key_vault_private_dns_vnet_link_name

  resource_group_name = var.create_primary_key_vault_private_dns_zone ? (
    var.primary_key_vault_private_dns_zone_resource_group_name
  ) : try(split("/", local.primary_key_vault_private_dns_zone_id)[4], null)

  private_dns_zone_name = var.create_primary_key_vault_private_dns_zone ? (
    var.primary_key_vault_private_dns_zone_name
  ) : try(split("/", local.primary_key_vault_private_dns_zone_id)[8], null)

  virtual_network_id   = local.primary_vnet_id
  registration_enabled = false

  tags = merge(local.common_tags, { Role = "Primary-CMK-DNS-Link" })
}

resource "azurerm_private_dns_zone" "dr_key_vault" {
  count = var.create_dr_key_vault_private_dns_zone ? 1 : 0

  name                = var.dr_key_vault_private_dns_zone_name
  resource_group_name = var.dr_key_vault_private_dns_zone_resource_group_name

  tags = merge(local.common_tags, { Role = "DR-CMK-DNS" })
}

resource "azurerm_private_dns_zone_virtual_network_link" "dr_key_vault" {
  count = var.create_dr_key_vault_private_dns_vnet_link ? 1 : 0

  name = var.dr_key_vault_private_dns_vnet_link_name

  resource_group_name = var.create_dr_key_vault_private_dns_zone ? (
    var.dr_key_vault_private_dns_zone_resource_group_name
  ) : try(split("/", local.dr_key_vault_private_dns_zone_id)[4], null)

  private_dns_zone_name = var.create_dr_key_vault_private_dns_zone ? (
    var.dr_key_vault_private_dns_zone_name
  ) : try(split("/", local.dr_key_vault_private_dns_zone_id)[8], null)

  virtual_network_id   = local.dr_vnet_id
  registration_enabled = false

  tags = merge(local.common_tags, { Role = "DR-CMK-DNS-Link" })
}
# =============================================================================
# USER-ASSIGNED IDENTITIES - CREATE NEW / USE EXISTING
# =============================================================================
resource "azurerm_user_assigned_identity" "primary" {
  count               = var.create_primary_user_assigned_identity ? 1 : 0
  name                = var.primary_user_assigned_identity_name
  location            = var.primary_location
  resource_group_name = var.primary_resource_group_name
  tags                = merge(local.common_tags, { Role = "Primary" })

  depends_on = [azurerm_resource_group.primary]
}

resource "azurerm_user_assigned_identity" "dr" {
  count               = var.create_dr_user_assigned_identity ? 1 : 0
  name                = var.dr_user_assigned_identity_name
  location            = var.dr_location
  resource_group_name = var.dr_resource_group_name
  tags                = merge(local.common_tags, { Role = "DR" })

  depends_on = [azurerm_resource_group.dr]
}
# =============================================================================
# EXISTING USER-ASSIGNED IDENTITIES - READ ONLY
# =============================================================================

data "azurerm_user_assigned_identity" "primary_existing" {
  count = !var.create_primary_user_assigned_identity && var.existing_primary_user_assigned_identity_id != null ? 1 : 0

  name                = local.existing_primary_uami_name
  resource_group_name = local.existing_primary_uami_rg
}

data "azurerm_user_assigned_identity" "dr_existing" {
  count = !var.create_dr_user_assigned_identity && var.existing_dr_user_assigned_identity_id != null ? 1 : 0

  name                = local.existing_dr_uami_name
  resource_group_name = local.existing_dr_uami_rg
}
# =============================================================================
# PRIMARY POSTGRESQL FLEXIBLE SERVER - CREATE NEW / USE EXISTING
# =============================================================================
resource "azurerm_postgresql_flexible_server" "primary" {
  count = var.create_primary_server ? 1 : 0

  name                = var.primary_server_name
  resource_group_name = var.primary_resource_group_name
  location            = var.primary_location
  create_mode         = var.primary_create_mode

  source_server_id                  = var.primary_source_server_id
  point_in_time_restore_time_in_utc = var.primary_point_in_time_restore_time_in_utc

  version                       = var.postgresql_version
  sku_name                      = var.sku_name
  storage_mb                    = var.storage_mb
  storage_tier                  = var.storage_tier
  auto_grow_enabled             = var.auto_grow_enabled
  backup_retention_days         = var.backup_retention_days
  geo_redundant_backup_enabled  = var.geo_redundant_backup_enabled
  zone                          = var.primary_zone
  public_network_access_enabled = var.networking_mode == "public"

  delegated_subnet_id = var.networking_mode == "vnet_integration" ? local.primary_delegated_subnet_id : null
  private_dns_zone_id = var.networking_mode == "vnet_integration" ? local.vnet_integration_private_dns_zone_id : null

  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password

  dynamic "authentication" {
    for_each = var.authentication == null ? [] : [var.authentication]
    content {
      password_auth_enabled         = authentication.value.password_auth_enabled
      active_directory_auth_enabled = authentication.value.active_directory_auth_enabled
      tenant_id = try(authentication.value.tenant_id, null) != null ? authentication.value.tenant_id : (
        authentication.value.active_directory_auth_enabled ? var.tenant_id : null
      )
    }
  }

  dynamic "high_availability" {
    for_each = var.primary_high_availability == null ? [] : [var.primary_high_availability]
    content {
      mode                      = high_availability.value.mode
      standby_availability_zone = try(high_availability.value.standby_availability_zone, null)
    }
  }

  dynamic "maintenance_window" {
    for_each = var.maintenance_window == null ? [] : [var.maintenance_window]
    content {
      day_of_week  = maintenance_window.value.day_of_week
      start_hour   = maintenance_window.value.start_hour
      start_minute = maintenance_window.value.start_minute
    }
  }

  dynamic "identity" {
    for_each = local.primary_identity_type == null ? [] : [1]
    content {
      type         = local.primary_identity_type
      identity_ids = length(local.primary_identity_ids) > 0 ? local.primary_identity_ids : null
    }
  }

  dynamic "customer_managed_key" {
    for_each = var.primary_customer_managed_key == null ? [] : [var.primary_customer_managed_key]
    content {
      key_vault_key_id                     = local.primary_cmk_key_id
      primary_user_assigned_identity_id    = local.primary_cmk_primary_uami_id
      geo_backup_key_vault_key_id          = try(customer_managed_key.value.geo_backup_key_vault_key_id, null)
      geo_backup_user_assigned_identity_id = try(customer_managed_key.value.geo_backup_user_assigned_identity_id, null)
    }
  }

  dynamic "cluster" {
    for_each = var.deployment_type == "elastic_cluster" && var.elastic_cluster != null ? [var.elastic_cluster] : []
    content {
      size                  = cluster.value.size
      default_database_name = try(cluster.value.default_database_name, null)
    }
  }

  tags = merge(local.common_tags, { Role = "Primary" })

  depends_on = [
    azurerm_resource_group.primary,
    azurerm_subnet.primary_delegated,
    azurerm_private_dns_zone.postgresql,
    azurerm_user_assigned_identity.primary,
    azurerm_key_vault_key.primary_postgresql,
    azurerm_role_assignment.primary_cmk_crypto
  ]
}

# Existing server lookup is read-only. It does not import/take ownership.
data "azurerm_postgresql_flexible_server" "primary_existing" {
  count               = !var.create_primary_server && var.existing_primary_server_id != null ? 1 : 0
  name                = local.existing_primary_name
  resource_group_name = local.existing_primary_rg
}

locals {
  primary_server_id             = var.create_primary_server ? azurerm_postgresql_flexible_server.primary[0].id : var.existing_primary_server_id
  primary_server_name_effective = var.create_primary_server ? azurerm_postgresql_flexible_server.primary[0].name : local.existing_primary_name
  primary_server_rg_effective   = var.create_primary_server ? var.primary_resource_group_name : local.existing_primary_rg
  primary_server_fqdn = var.create_primary_server ? azurerm_postgresql_flexible_server.primary[0].fqdn : (
    var.existing_primary_server_id != null ? data.azurerm_postgresql_flexible_server.primary_existing[0].fqdn : null
  )
}

# =============================================================================
# DATABASES / PARAMETERS / ENTRA ADMINS ON EFFECTIVE PRIMARY
# =============================================================================
resource "azurerm_postgresql_flexible_server_database" "database" {
  for_each = local.primary_server_present ? var.database_definitions : {}

  name      = each.key
  server_id = local.primary_server_id
  charset   = each.value.charset
  collation = each.value.collation
}

resource "azurerm_postgresql_flexible_server_configuration" "primary" {
  for_each = local.primary_server_present ? local.primary_effective_server_parameters : {}

  name      = each.key
  server_id = local.primary_server_id
  value     = each.value
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "primary" {
  for_each = local.primary_server_present ? var.entra_administrators : {}

  server_name         = local.primary_server_name_effective
  resource_group_name = local.primary_server_rg_effective
  object_id           = each.value.object_id
  principal_name      = each.value.principal_name
  principal_type      = each.value.principal_type
  tenant_id           = try(each.value.tenant_id, null) != null ? each.value.tenant_id : var.tenant_id
}

# =============================================================================
# STANDALONE SECONDARY SERVER - SECONDARY-ONLY OR INDEPENDENT SECONDARY
# =============================================================================
resource "azurerm_postgresql_flexible_server" "secondary" {
  count = var.create_secondary_server ? 1 : 0

  name                = var.dr_server_name
  resource_group_name = var.dr_resource_group_name
  location            = var.dr_location
  create_mode         = "Default"

  version                       = var.postgresql_version
  sku_name                      = var.dr_sku_name != null ? var.dr_sku_name : var.sku_name
  storage_mb                    = var.dr_storage_mb != null ? var.dr_storage_mb : var.storage_mb
  storage_tier                  = var.dr_storage_tier != null ? var.dr_storage_tier : var.storage_tier
  auto_grow_enabled             = var.dr_auto_grow_enabled != null ? var.dr_auto_grow_enabled : var.auto_grow_enabled
  backup_retention_days         = var.dr_backup_retention_days
  geo_redundant_backup_enabled  = var.dr_geo_redundant_backup_enabled
  zone                          = var.dr_zone
  public_network_access_enabled = var.dr_networking_mode == "public"

  delegated_subnet_id = var.dr_networking_mode == "vnet_integration" ? local.dr_delegated_subnet_id : null
  private_dns_zone_id = var.dr_networking_mode == "vnet_integration" ? local.vnet_integration_private_dns_zone_id : null

  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password

  dynamic "authentication" {
    for_each = var.authentication == null ? [] : [var.authentication]
    content {
      password_auth_enabled         = authentication.value.password_auth_enabled
      active_directory_auth_enabled = authentication.value.active_directory_auth_enabled
      tenant_id = try(authentication.value.tenant_id, null) != null ? authentication.value.tenant_id : (
        authentication.value.active_directory_auth_enabled ? var.tenant_id : null
      )
    }
  }

  dynamic "high_availability" {
    for_each = var.dr_high_availability == null ? [] : [var.dr_high_availability]
    content {
      mode                      = high_availability.value.mode
      standby_availability_zone = try(high_availability.value.standby_availability_zone, null)
    }
  }

  dynamic "maintenance_window" {
    for_each = var.dr_maintenance_window == null ? [] : [var.dr_maintenance_window]
    content {
      day_of_week  = maintenance_window.value.day_of_week
      start_hour   = maintenance_window.value.start_hour
      start_minute = maintenance_window.value.start_minute
    }
  }

  dynamic "identity" {
    for_each = local.dr_identity_type == null ? [] : [1]
    content {
      type         = local.dr_identity_type
      identity_ids = length(local.dr_identity_ids) > 0 ? local.dr_identity_ids : null
    }
  }

  dynamic "customer_managed_key" {
    for_each = var.dr_customer_managed_key == null ? [] : [var.dr_customer_managed_key]
    content {
      key_vault_key_id                     = local.dr_cmk_key_id
      primary_user_assigned_identity_id    = local.dr_cmk_primary_uami_id
      geo_backup_key_vault_key_id          = try(customer_managed_key.value.geo_backup_key_vault_key_id, null)
      geo_backup_user_assigned_identity_id = try(customer_managed_key.value.geo_backup_user_assigned_identity_id, null)
    }
  }

  dynamic "cluster" {
    for_each = var.deployment_type == "elastic_cluster" && var.elastic_cluster != null ? [var.elastic_cluster] : []
    content {
      size                  = cluster.value.size
      default_database_name = try(cluster.value.default_database_name, null)
    }
  }

  tags = merge(local.common_tags, { Role = "Secondary-Standalone" })

  depends_on = [
    azurerm_resource_group.dr,
    azurerm_subnet.dr_delegated,
    azurerm_private_dns_zone.postgresql,
    azurerm_user_assigned_identity.dr,
    azurerm_key_vault_key.dr_postgresql,
    azurerm_role_assignment.dr_cmk_crypto
  ]
}

# =============================================================================
# DR READ REPLICA - CREATE NEW / USE EXISTING
# =============================================================================
resource "azurerm_postgresql_flexible_server" "dr_replica" {
  count = var.create_dr_replica ? 1 : 0

  name                = var.dr_server_name
  resource_group_name = var.dr_resource_group_name
  location            = var.dr_location
  create_mode         = "Replica"
  source_server_id    = local.primary_server_id

  sku_name                      = var.dr_sku_name
  storage_mb                    = var.dr_storage_mb
  storage_tier                  = var.dr_storage_tier
  auto_grow_enabled             = var.dr_auto_grow_enabled
  zone                          = var.dr_zone
  public_network_access_enabled = var.dr_networking_mode == "public"

  delegated_subnet_id = var.dr_networking_mode == "vnet_integration" ? local.dr_delegated_subnet_id : null
  private_dns_zone_id = var.dr_networking_mode == "vnet_integration" ? local.vnet_integration_private_dns_zone_id : null

  dynamic "identity" {
    for_each = local.dr_identity_type == null ? [] : [1]
    content {
      type         = local.dr_identity_type
      identity_ids = length(local.dr_identity_ids) > 0 ? local.dr_identity_ids : null
    }
  }

  dynamic "customer_managed_key" {
    for_each = var.dr_customer_managed_key == null ? [] : [var.dr_customer_managed_key]
    content {
      key_vault_key_id                     = local.dr_cmk_key_id
      primary_user_assigned_identity_id    = local.dr_cmk_primary_uami_id
      geo_backup_key_vault_key_id          = try(customer_managed_key.value.geo_backup_key_vault_key_id, null)
      geo_backup_user_assigned_identity_id = try(customer_managed_key.value.geo_backup_user_assigned_identity_id, null)
    }
  }

  tags = merge(local.common_tags, { Role = "DR-Read-Replica" })

  depends_on = [
    azurerm_resource_group.dr,
    azurerm_postgresql_flexible_server_database.database,
    azurerm_postgresql_flexible_server_configuration.primary,
    azurerm_subnet.dr_delegated,
    azurerm_private_dns_zone.postgresql,
    azurerm_user_assigned_identity.dr,
    azurerm_key_vault_key.dr_postgresql,
    azurerm_role_assignment.dr_cmk_crypto
  ]
}

data "azurerm_postgresql_flexible_server" "dr_existing" {
  count               = !var.create_dr_replica && !var.create_secondary_server && var.existing_dr_server_id != null ? 1 : 0
  name                = local.existing_dr_name
  resource_group_name = local.existing_dr_rg
}

locals {
  dr_server_id             = var.create_dr_replica ? azurerm_postgresql_flexible_server.dr_replica[0].id : (var.create_secondary_server ? azurerm_postgresql_flexible_server.secondary[0].id : var.existing_dr_server_id)
  dr_server_name_effective = var.create_dr_replica ? azurerm_postgresql_flexible_server.dr_replica[0].name : (var.create_secondary_server ? azurerm_postgresql_flexible_server.secondary[0].name : local.existing_dr_name)
  dr_server_rg_effective   = (var.create_dr_replica || var.create_secondary_server) ? var.dr_resource_group_name : local.existing_dr_rg
  dr_server_fqdn = var.create_dr_replica ? azurerm_postgresql_flexible_server.dr_replica[0].fqdn : (
    var.create_secondary_server ? azurerm_postgresql_flexible_server.secondary[0].fqdn : (
      var.existing_dr_server_id != null ? data.azurerm_postgresql_flexible_server.dr_existing[0].fqdn : null
    )
  )
}

resource "azurerm_postgresql_flexible_server_database" "secondary_database" {
  for_each = var.create_secondary_server ? var.secondary_database_definitions : {}

  name      = each.key
  server_id = local.dr_server_id
  charset   = each.value.charset
  collation = each.value.collation
}

resource "azurerm_postgresql_flexible_server_configuration" "dr" {
  for_each = local.dr_server_present ? local.dr_effective_server_parameters : {}

  name      = each.key
  server_id = local.dr_server_id
  value     = each.value
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "dr" {
  for_each = local.dr_server_present && var.manage_entra_administrators_on_dr ? var.entra_administrators : {}

  server_name         = local.dr_server_name_effective
  resource_group_name = local.dr_server_rg_effective
  object_id           = each.value.object_id
  principal_name      = each.value.principal_name
  principal_type      = each.value.principal_type
  tenant_id           = try(each.value.tenant_id, null) != null ? each.value.tenant_id : var.tenant_id
}

# =============================================================================
# ADDITIONAL READ REPLICAS - populated map = CREATE; empty map = not configured
# =============================================================================
resource "azurerm_postgresql_flexible_server" "additional_replica" {
  for_each = local.primary_server_present && var.deployment_type == "server" ? var.additional_read_replicas : {}

  name                = each.value.name
  resource_group_name = each.value.resource_group_name
  location            = each.value.location

  create_mode      = "Replica"
  source_server_id = local.primary_server_id

  sku_name          = try(each.value.sku_name, null)
  storage_mb        = try(each.value.storage_mb, null)
  storage_tier      = try(each.value.storage_tier, null)
  auto_grow_enabled = try(each.value.auto_grow_enabled, null)
  zone              = try(each.value.zone, null)

  public_network_access_enabled = each.value.networking_mode == "public"

  delegated_subnet_id = (
    each.value.networking_mode == "vnet_integration"
    ? try(each.value.delegated_subnet_id, null)
    : null
  )

  private_dns_zone_id = (
    each.value.networking_mode == "vnet_integration"
    ? try(each.value.private_dns_zone_id, null)
    : null
  )

  # Optional System Assigned + User Assigned Identity
  dynamic "identity" {
    for_each = (
      try(each.value.system_assigned_identity_enabled, false) ||
      try(each.value.user_assigned_identity_id, null) != null
    ) ? [1] : []

    content {
      type = (
        try(each.value.system_assigned_identity_enabled, false) &&
        try(each.value.user_assigned_identity_id, null) != null
        ? "SystemAssigned, UserAssigned"
        : try(each.value.system_assigned_identity_enabled, false)
        ? "SystemAssigned"
        : "UserAssigned"
      )

      identity_ids = (
        try(each.value.user_assigned_identity_id, null) != null
        ? [each.value.user_assigned_identity_id]
        : null
      )
    }
  }

  # Optional customer-managed key
  dynamic "customer_managed_key" {
    for_each = try(each.value.key_vault_key_id, null) != null ? [1] : []

    content {
      key_vault_key_id                  = each.value.key_vault_key_id
      primary_user_assigned_identity_id = each.value.user_assigned_identity_id
    }
  }

  tags = merge(
    local.common_tags,
    try(each.value.tags, {}),
    {
      Role = "Read-Replica"
    }
  )
}
# =============================================================================
# PRIVATE ENDPOINTS - CREATE NEW / USE EXISTING
# =============================================================================
resource "azurerm_private_endpoint" "primary_postgresql" {
  count = var.create_primary_private_endpoint ? 1 : 0

  name                = var.primary_private_endpoint_name
  location            = var.primary_location
  resource_group_name = var.primary_resource_group_name != null ? var.primary_resource_group_name : local.primary_server_rg_effective
  subnet_id           = local.primary_private_endpoint_subnet_id
  tags                = merge(local.common_tags, { Role = "Primary" })

  private_service_connection {
    name                           = "psc-${var.primary_private_endpoint_name}"
    private_connection_resource_id = local.primary_server_id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_endpoint_attach_dns_zone ? [1] : []
    content {
      name                 = "postgresql-dns-zone-group"
      private_dns_zone_ids = [local.private_dns_zone_id]
    }
  }
}

resource "azurerm_private_endpoint" "dr_postgresql" {
  count = var.create_dr_private_endpoint ? 1 : 0

  name                = var.dr_private_endpoint_name
  location            = var.dr_location
  resource_group_name = var.dr_resource_group_name != null ? var.dr_resource_group_name : local.dr_server_rg_effective
  subnet_id           = local.dr_private_endpoint_subnet_id
  tags                = merge(local.common_tags, { Role = "DR" })

  private_service_connection {
    name                           = "psc-${var.dr_private_endpoint_name}"
    private_connection_resource_id = local.dr_server_id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_endpoint_attach_dns_zone ? [1] : []
    content {
      name                 = "postgresql-dns-zone-group"
      private_dns_zone_ids = [local.private_dns_zone_id]
    }
  }
}
# =============================================================================
# ADDITIONAL READ REPLICA PRIVATE ENDPOINTS
# =============================================================================
resource "azurerm_private_endpoint" "additional_replica_postgresql" {
  for_each = {
    for key, replica in var.additional_read_replicas :
    key => replica
    if(
      replica.networking_mode == "private_endpoint" &&
      try(replica.create_private_endpoint, false)
    )
  }

  name                = each.value.private_endpoint_name
  location            = each.value.location
  resource_group_name = each.value.resource_group_name
  subnet_id           = each.value.private_endpoint_subnet_id

  private_service_connection {
    name = "psc-${each.value.private_endpoint_name}"

    private_connection_resource_id = (
      azurerm_postgresql_flexible_server.additional_replica[each.key].id
    )

    subresource_names    = ["postgresqlServer"]
    is_manual_connection = false
  }

  dynamic "private_dns_zone_group" {
    for_each = (
      try(each.value.private_endpoint_attach_dns_zone, true) &&
      local.private_dns_zone_id != null
    ) ? [1] : []

    content {
      name = "postgresql-dns-zone-group"

      private_dns_zone_ids = [
        local.private_dns_zone_id
      ]
    }
  }

  tags = merge(
    local.common_tags,
    try(each.value.tags, {}),
    {
      Role = "Read-Replica-Private-Endpoint"
    }
  )

  depends_on = [
    azurerm_postgresql_flexible_server.additional_replica
  ]
}
# =============================================================================
# KEY VAULT PRIVATE ENDPOINTS - PRIMARY / DR CREATE NEW / USE EXISTING
# =============================================================================
resource "azurerm_private_endpoint" "primary_key_vault" {
  count = var.create_primary_key_vault_private_endpoint ? 1 : 0

  name                = var.primary_key_vault_private_endpoint_name
  location            = var.primary_key_vault_location
  resource_group_name = var.primary_key_vault_resource_group_name

  subnet_id = var.primary_key_vault_private_endpoint_subnet_id != null ? (
    var.primary_key_vault_private_endpoint_subnet_id
  ) : local.primary_private_endpoint_subnet_id

  tags = merge(local.common_tags, { Role = "Primary-PostgreSQL-CMK-KeyVault" })

  private_service_connection {
    name                           = "psc-${var.primary_key_vault_private_endpoint_name}"
    private_connection_resource_id = local.primary_key_vault_id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = local.primary_key_vault_private_dns_zone_id != null ? [1] : []

    content {
      name                 = "primary-keyvault-dns-zone-group"
      private_dns_zone_ids = [local.primary_key_vault_private_dns_zone_id]
    }
  }

  depends_on = [
    azurerm_key_vault.primary_postgresql,
    azurerm_private_dns_zone.primary_key_vault,
    azurerm_private_dns_zone_virtual_network_link.primary_key_vault
  ]
}

resource "azurerm_private_endpoint" "dr_key_vault" {
  count = var.create_dr_key_vault_private_endpoint ? 1 : 0

  name                = var.dr_key_vault_private_endpoint_name
  location            = var.dr_key_vault_location
  resource_group_name = var.dr_key_vault_resource_group_name

  subnet_id = var.dr_key_vault_private_endpoint_subnet_id != null ? (
    var.dr_key_vault_private_endpoint_subnet_id
  ) : local.dr_private_endpoint_subnet_id

  tags = merge(local.common_tags, { Role = "DR-PostgreSQL-CMK-KeyVault" })

  private_service_connection {
    name                           = "psc-${var.dr_key_vault_private_endpoint_name}"
    private_connection_resource_id = local.dr_key_vault_id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  dynamic "private_dns_zone_group" {
    for_each = local.dr_key_vault_private_dns_zone_id != null ? [1] : []

    content {
      name                 = "dr-keyvault-dns-zone-group"
      private_dns_zone_ids = [local.dr_key_vault_private_dns_zone_id]
    }
  }

  depends_on = [
    azurerm_key_vault.dr_postgresql,
    azurerm_private_dns_zone.dr_key_vault,
    azurerm_private_dns_zone_virtual_network_link.dr_key_vault
  ]
}
# =============================================================================
# FIREWALL RULES - populated map = CREATE; empty map = not configured
# =============================================================================
resource "azurerm_postgresql_flexible_server_firewall_rule" "rule" {
  for_each = {
    for key, rule in var.firewall_rules : key => rule
    if(rule.target == "primary" && local.primary_server_present) || (rule.target == "dr" && local.dr_server_present)
  }

  name             = each.key
  server_id        = each.value.target == "primary" ? local.primary_server_id : local.dr_server_id
  start_ip_address = each.value.start_ip_address
  end_ip_address   = each.value.end_ip_address
}

# =============================================================================
# VIRTUAL ENDPOINTS - populated map = CREATE; existing IDs can be surfaced only
# =============================================================================
resource "azurerm_postgresql_flexible_server_virtual_endpoint" "endpoint" {
  for_each = local.primary_server_present && local.dr_server_present ? var.virtual_endpoints : {}

  name              = each.value.name
  source_server_id  = local.primary_server_id
  replica_server_id = local.dr_server_id
  type              = each.value.type
}

# =============================================================================
# ON-DEMAND BACKUPS - populated map = CREATE; empty map = not configured
# =============================================================================
resource "azurerm_postgresql_flexible_server_backup" "backup" {
  for_each = {
    for key, backup in var.on_demand_backups : key => backup
    if(backup.target == "primary" && local.primary_server_present) || (backup.target == "dr" && local.dr_server_present)
  }

  name      = each.value.name
  server_id = each.value.target == "primary" ? local.primary_server_id : local.dr_server_id
}

# =============================================================================
# LOG ANALYTICS - CREATE NEW / USE EXISTING
# =============================================================================
resource "azurerm_log_analytics_workspace" "postgresql" {
  count = var.create_log_analytics_workspace ? 1 : 0

  name                = var.log_analytics_workspace_name
  location            = var.log_analytics_location
  resource_group_name = var.log_analytics_resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = local.common_tags
}

# Diagnostic categories are discovered so the module does not hard-code cloud/API-specific categories.
data "azurerm_monitor_diagnostic_categories" "primary" {
  count       = var.enable_primary_diagnostics && local.primary_server_present ? 1 : 0
  resource_id = local.primary_server_id
}

data "azurerm_monitor_diagnostic_categories" "dr" {
  count       = var.enable_dr_diagnostics && local.dr_server_present ? 1 : 0
  resource_id = local.dr_server_id
}

data "azurerm_monitor_diagnostic_categories" "additional_replica" {
  for_each = {
    for key, replica in var.additional_read_replicas :
    key => replica
    if try(replica.enable_diagnostics, false)
  }

  resource_id = azurerm_postgresql_flexible_server.additional_replica[each.key].id
}

resource "azurerm_monitor_diagnostic_setting" "primary" {
  count = var.enable_primary_diagnostics && local.primary_server_present ? 1 : 0

  name                           = "diag-${local.primary_server_name_effective}"
  target_resource_id             = local.primary_server_id
  log_analytics_workspace_id     = local.log_analytics_workspace_id
  storage_account_id             = var.diagnostic_storage_account_id
  eventhub_name                  = var.diagnostic_eventhub_name
  eventhub_authorization_rule_id = var.diagnostic_eventhub_authorization_rule_id

  dynamic "enabled_log" {
    for_each = length(var.diagnostic_log_categories) > 0 ? var.diagnostic_log_categories : toset(data.azurerm_monitor_diagnostic_categories.primary[0].log_category_types)
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = length(var.diagnostic_metric_categories) > 0 ? var.diagnostic_metric_categories : toset(data.azurerm_monitor_diagnostic_categories.primary[0].metrics)
    content {
      category = enabled_metric.value
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "dr" {
  count = var.enable_dr_diagnostics && local.dr_server_present ? 1 : 0

  name                           = "diag-${local.dr_server_name_effective}"
  target_resource_id             = local.dr_server_id
  log_analytics_workspace_id     = local.log_analytics_workspace_id
  storage_account_id             = var.diagnostic_storage_account_id
  eventhub_name                  = var.diagnostic_eventhub_name
  eventhub_authorization_rule_id = var.diagnostic_eventhub_authorization_rule_id

  dynamic "enabled_log" {
    for_each = length(var.diagnostic_log_categories) > 0 ? var.diagnostic_log_categories : toset(data.azurerm_monitor_diagnostic_categories.dr[0].log_category_types)
    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = length(var.diagnostic_metric_categories) > 0 ? var.diagnostic_metric_categories : toset(data.azurerm_monitor_diagnostic_categories.dr[0].metrics)
    content {
      category = enabled_metric.value
    }
  }
}
# =============================================================================
# ADDITIONAL READ REPLICA DIAGNOSTIC SETTINGS
# =============================================================================
resource "azurerm_monitor_diagnostic_setting" "additional_replica" {
  for_each = {
    for key, replica in var.additional_read_replicas :
    key => replica
    if try(replica.enable_diagnostics, false)
  }

  name = "diag-${azurerm_postgresql_flexible_server.additional_replica[each.key].name}"

  target_resource_id = azurerm_postgresql_flexible_server.additional_replica[each.key].id

  # Reuse existing/effective Log Analytics Workspace
  log_analytics_workspace_id = local.log_analytics_workspace_id

  storage_account_id             = var.diagnostic_storage_account_id
  eventhub_name                  = var.diagnostic_eventhub_name
  eventhub_authorization_rule_id = var.diagnostic_eventhub_authorization_rule_id

  dynamic "enabled_log" {
    for_each = (
      length(var.diagnostic_log_categories) > 0
      ? var.diagnostic_log_categories
      : toset(data.azurerm_monitor_diagnostic_categories.additional_replica[each.key].log_category_types)
    )

    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = (
      length(var.diagnostic_metric_categories) > 0
      ? var.diagnostic_metric_categories
      : toset(data.azurerm_monitor_diagnostic_categories.additional_replica[each.key].metrics)
    )

    content {
      category = enabled_metric.value
    }
  }
}
resource "azurerm_monitor_metric_alert" "postgresql" {
  for_each = var.metric_alerts

  name                = each.key
  resource_group_name = each.value.target == "primary" ? local.primary_server_rg_effective : local.dr_server_rg_effective
  scopes              = [each.value.target == "primary" ? local.primary_server_id : local.dr_server_id]
  description         = try(each.value.description, null)
  severity            = each.value.severity
  frequency           = each.value.frequency
  window_size         = each.value.window_size

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = each.value.metric_name
    aggregation      = each.value.aggregation
    operator         = each.value.operator
    threshold        = each.value.threshold
  }

  dynamic "action" {
    for_each = setunion(
      each.value.action_group_ids,
      each.value.use_default_action_group && local.monitor_action_group_id != null ? toset([local.monitor_action_group_id]) : toset([])
    )
    content {
      action_group_id = action.value
    }
  }

  tags = local.common_tags
}


# =============================================================================
# DEFENDER FOR CLOUD / ADVANCED THREAT PROTECTION - explicit management only
# =============================================================================
resource "azurerm_security_center_subscription_pricing" "open_source_relational_databases" {
  count = var.defender_subscription_plan_tier == null ? 0 : 1

  tier          = var.defender_subscription_plan_tier
  resource_type = "OpenSourceRelationalDatabases"

  # Removing a managed subscription pricing resource can change the Defender plan.
  # Keep it managed and change tier explicitly (Standard/Free), or remove it from state
  # if ownership is transferred to a central security subscription module.
  lifecycle {
    prevent_destroy = true
  }
}

resource "azapi_resource" "primary_advanced_threat_protection" {
  count = var.primary_defender_threat_protection_state != null && local.primary_server_present ? 1 : 0

  type      = "Microsoft.DBforPostgreSQL/flexibleServers/advancedThreatProtectionSettings@2025-08-01"
  name      = "Default"
  parent_id = local.primary_server_id
  body = {
    properties = {
      state = var.primary_defender_threat_protection_state
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azapi_resource" "dr_advanced_threat_protection" {
  count = var.dr_defender_threat_protection_state != null && local.dr_server_present ? 1 : 0

  type      = "Microsoft.DBforPostgreSQL/flexibleServers/advancedThreatProtectionSettings@2025-08-01"
  name      = "Default"
  parent_id = local.dr_server_id
  body = {
    properties = {
      state = var.dr_defender_threat_protection_state
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

# =============================================================================
# KEY VAULT / KEY FOR CMK - PRIMARY / DR CREATE NEW / USE EXISTING
# =============================================================================
resource "azurerm_key_vault" "primary_postgresql" {
  count = var.create_primary_key_vault ? 1 : 0

  name                = var.primary_key_vault_name
  location            = var.primary_key_vault_location
  resource_group_name = var.primary_key_vault_resource_group_name
  tenant_id           = coalesce(var.tenant_id, data.azurerm_client_config.current.tenant_id)
  sku_name            = var.primary_key_vault_sku_name

  rbac_authorization_enabled = var.primary_key_vault_rbac_authorization_enabled
  purge_protection_enabled   = var.primary_key_vault_purge_protection_enabled

  # Enterprise CMK vaults remain private-only.
  public_network_access_enabled = false

  soft_delete_retention_days = var.primary_key_vault_soft_delete_retention_days

  network_acls {
    bypass                     = var.primary_key_vault_network_acls.bypass
    default_action             = var.primary_key_vault_network_acls.default_action
    ip_rules                   = var.primary_key_vault_network_acls.ip_rules
    virtual_network_subnet_ids = var.primary_key_vault_network_acls.virtual_network_subnet_ids
  }

  tags = merge(local.common_tags, { Role = "Primary-CMK-KeyVault" })

  depends_on = [azurerm_resource_group.primary]
}

resource "azurerm_key_vault" "dr_postgresql" {
  count = var.create_dr_key_vault ? 1 : 0

  name                = var.dr_key_vault_name
  location            = var.dr_key_vault_location
  resource_group_name = var.dr_key_vault_resource_group_name
  tenant_id           = coalesce(var.tenant_id, data.azurerm_client_config.current.tenant_id)
  sku_name            = var.dr_key_vault_sku_name

  rbac_authorization_enabled = var.dr_key_vault_rbac_authorization_enabled
  purge_protection_enabled   = var.dr_key_vault_purge_protection_enabled

  # Enterprise CMK vaults remain private-only.
  public_network_access_enabled = false

  soft_delete_retention_days = var.dr_key_vault_soft_delete_retention_days

  network_acls {
    bypass                     = var.dr_key_vault_network_acls.bypass
    default_action             = var.dr_key_vault_network_acls.default_action
    ip_rules                   = var.dr_key_vault_network_acls.ip_rules
    virtual_network_subnet_ids = var.dr_key_vault_network_acls.virtual_network_subnet_ids
  }

  tags = merge(local.common_tags, { Role = "DR-CMK-KeyVault" })

  depends_on = [azurerm_resource_group.dr]
}

resource "azurerm_key_vault_key" "primary_postgresql" {
  count = var.create_primary_key_vault_key ? 1 : 0

  name         = var.primary_key_vault_key_name
  key_vault_id = local.primary_key_vault_id
  key_type     = var.primary_key_vault_key_type
  key_size     = contains(["RSA", "RSA-HSM"], var.primary_key_vault_key_type) ? var.primary_key_vault_key_size : null
  curve        = contains(["EC", "EC-HSM"], var.primary_key_vault_key_type) ? var.primary_key_vault_key_curve : null
  key_opts     = sort(tolist(var.primary_key_vault_key_opts))
  tags         = merge(local.common_tags, { Role = "Primary-CMK-Key" })

  # With public access disabled, ensure the regional private DNS/link/PE path
  # exists before Terraform attempts data-plane key creation.
  depends_on = [
    azurerm_key_vault.primary_postgresql,
    azurerm_private_dns_zone_virtual_network_link.primary_key_vault,
    azurerm_private_endpoint.primary_key_vault
  ]
}

resource "azurerm_key_vault_key" "dr_postgresql" {
  count = var.create_dr_key_vault_key ? 1 : 0

  name         = var.dr_key_vault_key_name
  key_vault_id = local.dr_key_vault_id
  key_type     = var.dr_key_vault_key_type
  key_size     = contains(["RSA", "RSA-HSM"], var.dr_key_vault_key_type) ? var.dr_key_vault_key_size : null
  curve        = contains(["EC", "EC-HSM"], var.dr_key_vault_key_type) ? var.dr_key_vault_key_curve : null
  key_opts     = sort(tolist(var.dr_key_vault_key_opts))
  tags         = merge(local.common_tags, { Role = "DR-CMK-Key" })

  depends_on = [
    azurerm_key_vault.dr_postgresql,
    azurerm_private_dns_zone_virtual_network_link.dr_key_vault,
    azurerm_private_endpoint.dr_key_vault
  ]
}

# =============================================================================
# AZURE BACKUP / LONG-TERM RETENTION - CREATE NEW / USE EXISTING
# =============================================================================
resource "azurerm_data_protection_backup_vault" "postgresql" {
  count = var.create_backup_vault ? 1 : 0

  name                         = var.backup_vault_name
  resource_group_name          = var.backup_vault_resource_group_name
  location                     = var.backup_vault_location
  datastore_type               = "VaultStore"
  redundancy                   = var.backup_vault_redundancy
  cross_region_restore_enabled = var.backup_vault_cross_region_restore_enabled
  soft_delete                  = var.backup_vault_soft_delete
  retention_duration_in_days   = var.backup_vault_retention_duration_in_days

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags

  depends_on = [azurerm_resource_group.primary, azurerm_resource_group.dr]
}

resource "azurerm_role_assignment" "ltr_reader" {
  count = var.manage_ltr_role_assignments && (var.create_backup_vault || var.existing_backup_vault_id != null) && local.primary_server_present ? 1 : 0

  scope                = "/subscriptions/${var.subscription_id}/resourceGroups/${local.primary_server_rg_effective}"
  role_definition_name = "Reader"
  principal_id         = local.backup_vault_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "ltr_server_backup" {
  count = var.manage_ltr_role_assignments && (var.create_backup_vault || var.existing_backup_vault_id != null) && local.primary_server_present ? 1 : 0

  scope                = local.primary_server_id
  role_definition_name = "PostgreSQL Flexible Server Long Term Retention Backup Role"
  principal_id         = local.backup_vault_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_data_protection_backup_policy_postgresql_flexible_server" "postgresql" {
  count = var.create_backup_policy ? 1 : 0

  name                            = var.backup_policy_name
  vault_id                        = local.backup_vault_id
  backup_repeating_time_intervals = var.backup_repeating_time_intervals
  time_zone                       = var.backup_policy_time_zone

  default_retention_rule {
    life_cycle {
      duration        = var.backup_policy_default_retention_duration
      data_store_type = "VaultStore"
    }
  }

  dynamic "retention_rule" {
    for_each = var.backup_policy_retention_rules
    content {
      name     = retention_rule.key
      priority = retention_rule.value.priority

      life_cycle {
        duration        = retention_rule.value.duration
        data_store_type = "VaultStore"
      }

      criteria {
        absolute_criteria      = try(retention_rule.value.absolute_criteria, null)
        days_of_week           = length(try(retention_rule.value.days_of_week, [])) > 0 ? sort(tolist(retention_rule.value.days_of_week)) : null
        months_of_year         = length(try(retention_rule.value.months_of_year, [])) > 0 ? sort(tolist(retention_rule.value.months_of_year)) : null
        weeks_of_month         = length(try(retention_rule.value.weeks_of_month, [])) > 0 ? sort(tolist(retention_rule.value.weeks_of_month)) : null
        scheduled_backup_times = length(try(retention_rule.value.scheduled_backup_times, [])) > 0 ? sort(tolist(retention_rule.value.scheduled_backup_times)) : null
      }
    }
  }

  depends_on = [azurerm_role_assignment.ltr_reader, azurerm_role_assignment.ltr_server_backup]
}

resource "azurerm_data_protection_backup_instance_postgresql_flexible_server" "postgresql" {
  count = var.create_ltr_backup_instance ? 1 : 0

  name             = var.ltr_backup_instance_name
  location         = coalesce(var.ltr_backup_instance_location, var.primary_location)
  vault_id         = local.backup_vault_id
  server_id        = local.primary_server_id
  backup_policy_id = local.backup_policy_id

  depends_on = [azurerm_role_assignment.ltr_reader, azurerm_role_assignment.ltr_server_backup]
}

# =============================================================================
# MONITOR ACTION GROUP / WORKBOOK - CREATE NEW / USE EXISTING
# =============================================================================
resource "azurerm_monitor_action_group" "postgresql" {
  count = var.create_monitor_action_group ? 1 : 0

  name                = var.monitor_action_group_name
  resource_group_name = var.monitor_action_group_resource_group_name
  short_name          = var.monitor_action_group_short_name
  location            = var.monitor_action_group_location
  enabled             = var.monitor_action_group_enabled

  dynamic "email_receiver" {
    for_each = var.action_group_email_receivers
    content {
      name                    = email_receiver.key
      email_address           = email_receiver.value.email_address
      use_common_alert_schema = try(email_receiver.value.use_common_alert_schema, null)
    }
  }

  dynamic "sms_receiver" {
    for_each = var.action_group_sms_receivers
    content {
      name         = sms_receiver.key
      country_code = sms_receiver.value.country_code
      phone_number = sms_receiver.value.phone_number
    }
  }

  dynamic "webhook_receiver" {
    for_each = var.action_group_webhook_receivers
    content {
      name                    = webhook_receiver.key
      service_uri             = webhook_receiver.value.service_uri
      use_common_alert_schema = try(webhook_receiver.value.use_common_alert_schema, null)
    }
  }

  tags = local.common_tags
}

resource "azurerm_application_insights_workbook" "postgresql" {
  count = var.create_monitor_workbook ? 1 : 0

  name                = var.monitor_workbook_name
  resource_group_name = var.monitor_workbook_resource_group_name
  location            = var.monitor_workbook_location
  display_name        = var.monitor_workbook_display_name
  data_json           = var.monitor_workbook_data_json
  source_id           = var.monitor_workbook_source_id
  tags                = local.common_tags
}

# =============================================================================
# ADVISOR SUPPRESSIONS - Advisor recommendations themselves are Azure-generated
# =============================================================================
resource "azurerm_advisor_suppression" "postgresql" {
  for_each = var.advisor_suppressions

  name              = each.key
  recommendation_id = each.value.recommendation_id
  resource_id       = each.value.resource_id
  ttl               = try(each.value.ttl, null)
}

# =============================================================================
# LOCKS / RBAC - explicit input only
# =============================================================================
resource "azurerm_management_lock" "primary_server" {
  count = var.primary_server_lock_level != null && local.primary_server_present ? 1 : 0

  name       = "lock-${local.primary_server_name_effective}"
  scope      = local.primary_server_id
  lock_level = var.primary_server_lock_level
  notes      = "Managed by Terraform Azure PostgreSQL module"
}

resource "azurerm_management_lock" "dr_server" {
  count = var.dr_server_lock_level != null && local.dr_server_present ? 1 : 0

  name       = "lock-${local.dr_server_name_effective}"
  scope      = local.dr_server_id
  lock_level = var.dr_server_lock_level
  notes      = "Managed by Terraform Azure PostgreSQL module"
}

resource "azurerm_role_assignment" "primary_cmk_crypto" {
  count = (
    (var.create_cmk_role_assignments || var.create_primary_cmk_role_assignment) &&
    (
      var.create_primary_user_assigned_identity ||
      var.existing_primary_user_assigned_identity_id != null
    ) &&
    (
      var.create_primary_key_vault ||
      var.existing_primary_key_vault_id != null
    )
  ) ? 1 : 0

  scope                = local.primary_key_vault_id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = local.primary_uami_principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_key_vault.primary_postgresql]
}

resource "azurerm_role_assignment" "dr_cmk_crypto" {
  count = (
    (var.create_cmk_role_assignments || var.create_dr_cmk_role_assignment) &&
    var.dr_customer_managed_key != null &&
    (
      var.create_dr_user_assigned_identity ||
      var.existing_dr_user_assigned_identity_id != null
    ) &&
    (
      var.create_dr_key_vault ||
      var.existing_dr_key_vault_id != null
    )
  ) ? 1 : 0

  scope                = local.dr_key_vault_id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = local.dr_uami_principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_key_vault.dr_postgresql]
}

resource "azurerm_role_assignment" "assignment" {
  for_each = var.role_assignments

  scope                = contains(keys(local.role_scope_aliases), each.value.scope) ? local.role_scope_aliases[each.value.scope] : each.value.scope
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
  principal_type       = try(each.value.principal_type, null)
}
