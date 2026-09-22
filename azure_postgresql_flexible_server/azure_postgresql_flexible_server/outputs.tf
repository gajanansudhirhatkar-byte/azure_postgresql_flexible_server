output "deployment_mode" {
  description = "Create-new / use-existing / not-managed summary for major resources."
  value = {
    deployment_type          = var.deployment_type
    primary_resource_group   = var.create_primary_resource_group ? "created" : (var.primary_resource_group_name != null ? "existing" : "not-configured")
    dr_resource_group        = var.create_dr_resource_group ? "created" : (var.dr_resource_group_name != null ? "existing" : "not-configured")
    primary_network          = var.create_primary_networking ? "created" : (var.primary_vnet_id != null ? "existing" : "not-configured")
    dr_network               = var.create_dr_networking ? "created" : (var.dr_vnet_id != null ? "existing" : "not-configured")
    private_dns_zone         = var.create_private_dns_zone ? "created" : (var.existing_private_dns_zone_id != null ? "existing" : "not-configured")
    primary_server           = var.create_primary_server ? "created" : (var.existing_primary_server_id != null ? "existing" : "not-configured")
    dr_server                = var.create_dr_replica ? "created-read-replica" : (var.create_secondary_server ? "created-standalone-secondary" : (var.existing_dr_server_id != null ? "existing" : "not-configured"))
    primary_private_endpoint = var.create_primary_private_endpoint ? "created" : (var.existing_primary_private_endpoint_id != null ? "existing" : "not-configured")
    dr_private_endpoint      = var.create_dr_private_endpoint ? "created" : (var.existing_dr_private_endpoint_id != null ? "existing" : "not-configured")
    log_analytics = var.create_log_analytics_workspace ? "created" : (
      var.existing_log_analytics_workspace_id != null ? "existing" : "not-configured"
    )
    primary_uami = var.create_primary_user_assigned_identity ? "created" : (
      var.existing_primary_user_assigned_identity_id != null ? "existing" : "not-configured"
    )
    dr_uami = var.create_dr_user_assigned_identity ? "created" : (
      var.existing_dr_user_assigned_identity_id != null ? "existing" : "not-configured"
    )
    primary_key_vault                  = var.create_primary_key_vault ? "created" : (var.existing_primary_key_vault_id != null ? "existing" : "not-configured")
    dr_key_vault                       = var.create_dr_key_vault ? "created" : (var.existing_dr_key_vault_id != null ? "existing" : "not-configured")
    primary_key_vault_key              = var.create_primary_key_vault_key ? "created" : (var.existing_primary_key_vault_key_id != null ? "existing" : "not-configured")
    dr_key_vault_key                   = var.create_dr_key_vault_key ? "created" : (var.existing_dr_key_vault_key_id != null ? "existing" : "not-configured")
    primary_key_vault_private_dns      = var.create_primary_key_vault_private_dns_zone ? "created" : (var.existing_primary_key_vault_private_dns_zone_id != null ? "existing" : "not-configured")
    dr_key_vault_private_dns           = var.create_dr_key_vault_private_dns_zone ? "created" : (var.existing_dr_key_vault_private_dns_zone_id != null ? "existing" : "not-configured")
    primary_key_vault_private_endpoint = var.create_primary_key_vault_private_endpoint ? "created" : (var.existing_primary_key_vault_private_endpoint_id != null ? "existing" : "not-configured")
    dr_key_vault_private_endpoint      = var.create_dr_key_vault_private_endpoint ? "created" : (var.existing_dr_key_vault_private_endpoint_id != null ? "existing" : "not-configured")
    primary_key_vault_dns_vnet_link    = var.create_primary_key_vault_private_dns_vnet_link ? "created" : "not-configured"
    dr_key_vault_dns_vnet_link         = var.create_dr_key_vault_private_dns_vnet_link ? "created" : "not-configured"
    primary_cmk_rbac                   = (var.create_cmk_role_assignments || var.create_primary_cmk_role_assignment) && var.primary_customer_managed_key != null ? "managed" : "not-configured"
    dr_cmk_rbac                        = (var.create_cmk_role_assignments || var.create_dr_cmk_role_assignment) && var.dr_customer_managed_key != null ? "managed" : "not-configured"
    backup_vault                       = var.create_backup_vault ? "created" : (var.existing_backup_vault_id != null ? "existing" : "not-configured")
    backup_policy                      = var.create_backup_policy ? "created" : (var.existing_backup_policy_id != null ? "existing" : "not-configured")
    ltr_backup_instance                = var.create_ltr_backup_instance ? "created" : (var.existing_ltr_backup_instance_id != null ? "existing" : "not-configured")
    monitor_action_group               = var.create_monitor_action_group ? "created" : (var.existing_monitor_action_group_id != null ? "existing" : "not-configured")
    monitor_workbook                   = var.create_monitor_workbook ? "created" : (var.existing_monitor_workbook_id != null ? "existing" : "not-configured")
  }
}

output "primary_server_id" {
  description = "Effective primary PostgreSQL Flexible Server ID, or null when not managed."
  value       = local.primary_server_id
}

output "primary_server_name" {
  description = "Effective primary server name, or null when not managed."
  value       = local.primary_server_name_effective
}

output "primary_fqdn" {
  description = "Effective primary server FQDN, or null when not managed."
  value       = local.primary_server_fqdn
}

output "dr_server_id" {
  description = "Effective DR PostgreSQL server ID, or null when not managed."
  value       = local.dr_server_id
}

output "dr_server_name" {
  description = "Effective DR server name, or null when not managed."
  value       = local.dr_server_name_effective
}

output "dr_fqdn" {
  description = "Effective DR server FQDN, or null when not managed."
  value       = local.dr_server_fqdn
}

output "primary_vnet_id" {
  description = "Effective primary VNet ID, or null when not managed."
  value       = local.primary_vnet_id
}

output "dr_vnet_id" {
  description = "Effective DR VNet ID, or null when not managed."
  value       = local.dr_vnet_id
}

output "primary_private_endpoint_subnet_id" {
  description = "Effective primary Private Endpoint subnet ID, or null."
  value       = local.primary_private_endpoint_subnet_id
}

output "dr_private_endpoint_subnet_id" {
  description = "Effective DR Private Endpoint subnet ID, or null."
  value       = local.dr_private_endpoint_subnet_id
}

output "primary_delegated_subnet_id" {
  description = "Effective primary delegated subnet ID for VNet integration, or null."
  value       = local.primary_delegated_subnet_id
}

output "dr_delegated_subnet_id" {
  description = "Effective DR delegated subnet ID for VNet integration, or null."
  value       = local.dr_delegated_subnet_id
}

output "private_dns_zone_id" {
  description = "Effective Private DNS zone ID, or null when not managed."
  value       = local.private_dns_zone_id
}

output "primary_private_endpoint_id" {
  description = "Created or supplied existing primary Private Endpoint ID, or null."
  value       = var.create_primary_private_endpoint ? azurerm_private_endpoint.primary_postgresql[0].id : var.existing_primary_private_endpoint_id
}

output "primary_private_endpoint_ip" {
  description = "Primary Private Endpoint IP when created by this module; null for existing/not-managed PE."
  value       = var.create_primary_private_endpoint ? azurerm_private_endpoint.primary_postgresql[0].private_service_connection[0].private_ip_address : null
}

output "dr_private_endpoint_id" {
  description = "Created or supplied existing DR Private Endpoint ID, or null."
  value       = var.create_dr_private_endpoint ? azurerm_private_endpoint.dr_postgresql[0].id : var.existing_dr_private_endpoint_id
}

output "dr_private_endpoint_ip" {
  description = "DR Private Endpoint IP when created by this module; null for existing/not-managed PE."
  value       = var.create_dr_private_endpoint ? azurerm_private_endpoint.dr_postgresql[0].private_service_connection[0].private_ip_address : null
}

output "primary_user_assigned_identity_id" {
  description = "Effective primary UAMI ID, or null."
  value       = local.primary_uami_id
}

output "dr_user_assigned_identity_id" {
  description = "Effective DR UAMI ID, or null."
  value       = local.dr_uami_id
}

output "log_analytics_workspace_id" {
  description = "Effective Log Analytics workspace ID, or null."
  value       = local.log_analytics_workspace_id
}

output "databases_managed" {
  description = "Database names created/managed by this module."
  value       = sort(keys(var.database_definitions))
}

output "primary_server_parameters_managed" {
  description = "Primary server configuration parameter names managed by this module."
  value       = sort(keys(local.primary_effective_server_parameters))
}

output "dr_server_parameters_managed" {
  description = "DR server configuration parameter names managed by this module."
  value       = sort(keys(local.dr_effective_server_parameters))
}

output "additional_read_replica_ids" {
  description = "IDs of additional read replicas created by this module."
  value       = { for k, v in azurerm_postgresql_flexible_server.additional_replica : k => v.id }
}

output "virtual_endpoint_ids" {
  description = "Created virtual endpoint IDs merged with explicitly supplied existing endpoint IDs."
  value       = merge(var.existing_virtual_endpoint_ids, { for k, v in azurerm_postgresql_flexible_server_virtual_endpoint.endpoint : k => v.id })
}

output "on_demand_backup_ids" {
  description = "On-demand backup IDs created by this module."
  value       = { for k, v in azurerm_postgresql_flexible_server_backup.backup : k => v.id }
}

output "deployment_type" {
  description = "Selected primary deployment shape: server or elastic_cluster."
  value       = var.deployment_type
}

output "primary_key_vault_id" {
  description = "Effective primary-region Key Vault ID for CMK support, or null."
  value       = local.primary_key_vault_id
}

output "dr_key_vault_id" {
  description = "Effective DR-region Key Vault ID for CMK support, or null."
  value       = local.dr_key_vault_id
}

output "primary_key_vault_key_id" {
  description = "Effective primary-region CMK Key Vault key ID, or null."
  value       = local.primary_key_vault_key_id
}

output "dr_key_vault_key_id" {
  description = "Effective DR-region CMK Key Vault key ID, or null."
  value       = local.dr_key_vault_key_id
}

output "primary_key_vault_private_dns_zone_id" {
  description = "Effective primary Key Vault Private DNS zone ID, or null."
  value       = local.primary_key_vault_private_dns_zone_id
}

output "dr_key_vault_private_dns_zone_id" {
  description = "Effective DR Key Vault Private DNS zone ID, or null."
  value       = local.dr_key_vault_private_dns_zone_id
}

output "primary_key_vault_private_endpoint_id" {
  description = "Created or supplied primary Key Vault Private Endpoint ID, or null."
  value       = local.primary_key_vault_private_endpoint_id
}

output "dr_key_vault_private_endpoint_id" {
  description = "Created or supplied DR Key Vault Private Endpoint ID, or null."
  value       = local.dr_key_vault_private_endpoint_id
}

output "primary_key_vault_dns_vnet_link_id" {
  description = "Primary Key Vault Private DNS VNet link ID when created by this module, or null."
  value       = var.create_primary_key_vault_private_dns_vnet_link ? azurerm_private_dns_zone_virtual_network_link.primary_key_vault[0].id : null
}

output "dr_key_vault_dns_vnet_link_id" {
  description = "DR Key Vault Private DNS VNet link ID when created by this module, or null."
  value       = var.create_dr_key_vault_private_dns_vnet_link ? azurerm_private_dns_zone_virtual_network_link.dr_key_vault[0].id : null
}

output "primary_cmk_role_assignment_id" {
  description = "Primary Key Vault Crypto Service Encryption User role assignment ID when managed by this module, or null."
  value       = length(azurerm_role_assignment.primary_cmk_crypto) > 0 ? azurerm_role_assignment.primary_cmk_crypto[0].id : null
}

output "dr_cmk_role_assignment_id" {
  description = "DR Key Vault Crypto Service Encryption User role assignment ID when managed by this module, or null."
  value       = length(azurerm_role_assignment.dr_cmk_crypto) > 0 ? azurerm_role_assignment.dr_cmk_crypto[0].id : null
}

output "primary_effective_cmk_key_id" {
  description = "Key ID actually supplied to the primary PostgreSQL CMK block."
  value       = local.primary_cmk_key_id
}

output "dr_effective_cmk_key_id" {
  description = "Key ID actually supplied to the DR PostgreSQL CMK block."
  value       = local.dr_cmk_key_id
}

output "backup_vault_id" {
  description = "Effective Azure Data Protection Backup Vault ID, or null."
  value       = local.backup_vault_id
}

output "backup_policy_id" {
  description = "Effective PostgreSQL Flexible Server LTR backup policy ID, or null."
  value       = local.backup_policy_id
}

output "ltr_backup_instance_id" {
  description = "Effective PostgreSQL LTR backup instance ID, or null."
  value       = local.ltr_backup_instance_id
}

output "monitor_action_group_id" {
  description = "Effective Azure Monitor Action Group ID, or null."
  value       = local.monitor_action_group_id
}

output "monitor_workbook_id" {
  description = "Effective Azure Monitor Workbook ID, or null."
  value       = local.monitor_workbook_id
}

output "defender_management" {
  description = "Defender inputs managed by this deployment; null means Terraform preserves external management and does not manage the setting."
  value = {
    subscription_plan_tier    = var.defender_subscription_plan_tier
    primary_threat_protection = var.primary_defender_threat_protection_state
    dr_threat_protection      = var.dr_defender_threat_protection_state
  }
}

output "feature_state" {
  description = "Feature enablement summary. Empty maps/null blocks are not managed."
  value = {
    deployment_type               = var.deployment_type
    high_availability             = var.primary_high_availability != null
    maintenance_window            = var.maintenance_window != null
    elastic_cluster               = var.deployment_type == "elastic_cluster" && var.elastic_cluster != null
    authentication                = var.authentication != null
    primary_cmk                   = var.primary_customer_managed_key != null
    dr_cmk                        = var.dr_customer_managed_key != null
    databases                     = length(var.database_definitions) > 0
    server_parameters             = length(local.primary_effective_server_parameters) > 0
    query_store                   = var.query_store != null
    autonomous_tuning             = var.autonomous_tuning != null
    logging                       = var.logging != null
    entra_administrators          = length(var.entra_administrators) > 0
    firewall_rules                = length(var.firewall_rules) > 0
    virtual_endpoints             = length(var.virtual_endpoints) > 0
    additional_replicas           = length(var.additional_read_replicas) > 0
    on_demand_backups             = length(var.on_demand_backups) > 0
    primary_diagnostics           = var.enable_primary_diagnostics
    dr_diagnostics                = var.enable_dr_diagnostics
    metric_alerts                 = length(var.metric_alerts) > 0
    monitor_action_group          = local.monitor_action_group_id != null
    monitor_workbook              = local.monitor_workbook_id != null
    defender_subscription         = var.defender_subscription_plan_tier != null
    primary_defender              = var.primary_defender_threat_protection_state != null
    dr_defender                   = var.dr_defender_threat_protection_state != null
    long_term_retention           = local.ltr_backup_instance_id != null
    primary_key_vault_cmk_support = local.primary_key_vault_key_id != null
    dr_key_vault_cmk_support      = local.dr_key_vault_key_id != null
    primary_cmk_rbac              = var.create_cmk_role_assignments || var.create_primary_cmk_role_assignment
    dr_cmk_rbac                   = var.create_cmk_role_assignments || var.create_dr_cmk_role_assignment
    advisor_suppressions          = length(var.advisor_suppressions) > 0
    role_assignments              = length(var.role_assignments) > 0
  }
}

output "topology" {
  description = "Effective deployment topology."
  value = var.create_dr_replica ? "active-passive" : (
    var.create_primary_server || var.existing_primary_server_id != null ? (
      var.create_secondary_server || var.existing_dr_server_id != null ? "dual-independent" : "primary-only"
    ) : (var.create_secondary_server || var.existing_dr_server_id != null ? "secondary-only" : "not-configured")
  )
}

output "vnet_integration_private_dns_zone_id" {
  description = "Effective VNet-integration Private DNS zone ID."
  value       = local.vnet_integration_private_dns_zone_id
}
