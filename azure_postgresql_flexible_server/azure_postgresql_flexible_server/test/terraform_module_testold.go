package azuremanagedpostgresqltest

import (
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"testing"
)

func moduleRoot(t *testing.T) string {
	t.Helper()
	root, err := filepath.Abs("..")
	if err != nil {
		t.Fatalf("resolve module root: %v", err)
	}
	return root
}

func readFile(t *testing.T, path string) string {
	t.Helper()
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	return string(b)
}

func requireContains(t *testing.T, content string, values ...string) {
	t.Helper()
	for _, value := range values {
		if !strings.Contains(content, value) {
			t.Fatalf("expected content to contain %q", value)
		}
	}
}

func requireNotContains(t *testing.T, content string, values ...string) {
	t.Helper()
	for _, value := range values {
		if strings.Contains(content, value) {
			t.Fatalf("expected content not to contain %q", value)
		}
	}
}

func variableNames(content string) map[string]bool {
	re := regexp.MustCompile(`variable\s+"([A-Za-z0-9_]+)"`)
	out := map[string]bool{}
	for _, m := range re.FindAllStringSubmatch(content, -1) {
		out[m[1]] = true
	}
	return out
}

func varReferences(content string) map[string]bool {
	re := regexp.MustCompile(`var\.([A-Za-z0-9_]+)`)
	out := map[string]bool{}
	for _, m := range re.FindAllStringSubmatch(content, -1) {
		out[m[1]] = true
	}
	return out
}

func topLevelAssignments(content string) []string {
	re := regexp.MustCompile(`(?m)^([A-Za-z_][A-Za-z0-9_]*)\s*=`)
	out := []string{}
	for _, m := range re.FindAllStringSubmatch(content, -1) {
		out = append(out, m[1])
	}
	return out
}

func variableBlock(t *testing.T, vars, name string) string {
	t.Helper()
	startRe := regexp.MustCompile(`(?m)^\s*variable\s+"` + regexp.QuoteMeta(name) + `"\s*\{`)
	loc := startRe.FindStringIndex(vars)
	if loc == nil {
		t.Fatalf("variable %q not found", name)
	}

	start := strings.Index(vars[loc[0]:loc[1]], "{") + loc[0]
	depth := 0
	inString := false
	escaped := false

	for i := start; i < len(vars); i++ {
		c := vars[i]

		if escaped {
			escaped = false
			continue
		}
		if inString && c == '\\' {
			escaped = true
			continue
		}
		if c == '"' {
			inString = !inString
			continue
		}
		if inString {
			continue
		}

		switch c {
		case '{':
			depth++
		case '}':
			depth--
			if depth == 0 {
				return vars[loc[0] : i+1]
			}
		}
	}

	t.Fatalf("unterminated variable block %q", name)
	return ""
}

func requireVariableDefault(t *testing.T, vars, name, expected string) {
	t.Helper()
	block := variableBlock(t, vars, name)
	re := regexp.MustCompile(`(?m)^\s*default\s*=\s*` + regexp.QuoteMeta(expected) + `\s*$`)
	if !re.MatchString(block) {
		t.Fatalf("variable %s must default to %s", name, expected)
	}
}

func masterSamplePath(t *testing.T) string {
	t.Helper()
	root := moduleRoot(t)
	candidates := []string{
		filepath.Join(root, "sample", "sample.tfvars"),
		filepath.Join(root, "sample", "master.sample.tfvars"),
		filepath.Join(root, "sample", "master.sample.validated.tfvars"),
	}
	for _, p := range candidates {
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	t.Fatalf("master sample not found; expected one of: %v", candidates)
	return ""
}

func TestRequiredLayout(t *testing.T) {
	root := moduleRoot(t)
	required := []string{
		"main.tf",
		"outputs.tf",
		"variables.tf",
		"versions.tf",
		"sample",
		"test",
		"scripts",
		"docs",
		"README.md",
		filepath.Join("docs", "DR_RUNBOOK.md"),
		filepath.Join("docs", "SCENARIO_MATRIX.md"),
	}
	for _, item := range required {
		if _, err := os.Stat(filepath.Join(root, item)); err != nil {
			t.Errorf("required item missing: %s: %v", item, err)
		}
	}
}

func TestOperationalScriptsPresentAndDocumented(t *testing.T) {
	root := moduleRoot(t)
	required := []string{
		"deploy.ps1",
		"validate.ps1",
		"dr-status.ps1",
		"dr-promote.ps1",
		"dr-failover.ps1",
		"dr-failback.ps1",
		"feature-inventory.ps1",
		"create-on-demand-backup.ps1",
		"install-extensions.ps1",
		"test-private-connectivity.ps1",
	}
	for _, name := range required {
		path := filepath.Join(root, "scripts", name)
		content := readFile(t, path)
		requireContains(t, content, ".SYNOPSIS", ".DESCRIPTION")
	}
}

func TestAzureGovernmentPinnedProvidersAndLocalBackend(t *testing.T) {
	versions := readFile(t, filepath.Join(moduleRoot(t), "versions.tf"))
	requireContains(t, versions,
		`required_version = ">= 1.9.8, < 2.0.0"`,
		`version = "= 4.81.0"`,
		`version = "= 2.12.0"`,
		`provider "azurerm"`,
		`provider "azapi"`,
		`"usgovernment"`,
		`backend "local"`,
		`path = "terraform.tfstate"`,
	)
}

func TestAllCreateFlagsDefaultFalse(t *testing.T) {
	vars := readFile(t, filepath.Join(moduleRoot(t), "variables.tf"))
	declRe := regexp.MustCompile(`variable\s+"(create_[A-Za-z0-9_]+)"`)
	matches := declRe.FindAllStringSubmatch(vars, -1)
	if len(matches) < 20 {
		t.Fatalf("expected enterprise module to expose many create_* controls; found %d", len(matches))
	}
	for _, m := range matches {
		requireVariableDefault(t, vars, m[1], "false")
	}
}

func TestKeyVaultSecureDefaults(t *testing.T) {
	vars := readFile(t, filepath.Join(moduleRoot(t), "variables.tf"))

	for _, name := range []string{
		"primary_key_vault_rbac_authorization_enabled",
		"primary_key_vault_purge_protection_enabled",
		"dr_key_vault_rbac_authorization_enabled",
		"dr_key_vault_purge_protection_enabled",
	} {
		requireVariableDefault(t, vars, name, "true")
	}

	for _, name := range []string{
		"primary_key_vault_public_network_access_enabled",
		"dr_key_vault_public_network_access_enabled",
	} {
		requireVariableDefault(t, vars, name, "false")
	}
}

func TestOptionalBlocksDefaultDisabled(t *testing.T) {
	vars := readFile(t, filepath.Join(moduleRoot(t), "variables.tf"))
	for _, name := range []string{
		"primary_high_availability",
		"dr_high_availability",
		"maintenance_window",
		"dr_maintenance_window",
		"elastic_cluster",
		"authentication",
		"primary_customer_managed_key",
		"dr_customer_managed_key",
		"pgbouncer_enabled",
		"query_store",
		"autonomous_tuning",
		"logging",
	} {
		requireVariableDefault(t, vars, name, "null")
	}
}

func TestCreateExistingAndOptionalResourceInterfaces(t *testing.T) {
	root := moduleRoot(t)
	vars := readFile(t, filepath.Join(root, "variables.tf"))
	main := readFile(t, filepath.Join(root, "main.tf"))
	outputs := readFile(t, filepath.Join(root, "outputs.tf"))

	requireContains(t, vars,
		`variable "create_primary_server"`,
		`variable "existing_primary_server_id"`,
		`variable "create_dr_replica"`,
		`variable "create_secondary_server"`,
		`variable "existing_dr_server_id"`,
		`variable "create_private_dns_zone"`,
		`variable "existing_private_dns_zone_id"`,
		`variable "create_log_analytics_workspace"`,
		`variable "existing_log_analytics_workspace_id"`,
		`variable "create_primary_user_assigned_identity"`,
		`variable "existing_primary_user_assigned_identity_id"`,
		`variable "create_primary_key_vault"`,
		`variable "existing_primary_key_vault_id"`,
		`variable "create_dr_key_vault"`,
		`variable "existing_dr_key_vault_id"`,
		`variable "create_primary_key_vault_key"`,
		`variable "existing_primary_key_vault_key_id"`,
	)

	requireContains(t, main,
		`count = var.create_primary_server ? 1 : 0`,
		`count = var.create_dr_replica ? 1 : 0`,
		`count = var.create_secondary_server ? 1 : 0`,
		`count = var.create_primary_private_endpoint ? 1 : 0`,
		`count = var.create_dr_private_endpoint ? 1 : 0`,
	)

	requireContains(t, outputs, `"not-configured"`, `"existing"`, `"created"`)
}

func TestFeatureCollectionsAreOptIn(t *testing.T) {
	vars := readFile(t, filepath.Join(moduleRoot(t), "variables.tf"))
	for _, name := range []string{
		"database_definitions",
		"server_parameters",
		"entra_administrators",
		"firewall_rules",
		"additional_read_replicas",
		"virtual_endpoints",
		"existing_virtual_endpoint_ids",
		"on_demand_backups",
		"metric_alerts",
		"role_assignments",
		"advisor_suppressions",
		"action_group_email_receivers",
		"action_group_sms_receivers",
		"action_group_webhook_receivers",
	} {
		requireVariableDefault(t, vars, name, "{}")
	}
}

func TestPostgreSQLFlexibleServerFeatureCoverage(t *testing.T) {
	main := readFile(t, filepath.Join(moduleRoot(t), "main.tf"))
	requireContains(t, main,
		`dynamic "authentication"`,
		`dynamic "high_availability"`,
		`dynamic "maintenance_window"`,
		`dynamic "identity"`,
		`dynamic "customer_managed_key"`,
		`dynamic "cluster"`,
		`delegated_subnet_id`,
		`private_dns_zone_id`,
		`public_network_access_enabled`,
		`resource "azurerm_postgresql_flexible_server_configuration"`,
		`resource "azurerm_postgresql_flexible_server_active_directory_administrator"`,
		`resource "azurerm_postgresql_flexible_server_firewall_rule"`,
		`resource "azurerm_postgresql_flexible_server_virtual_endpoint"`,
		`resource "azurerm_postgresql_flexible_server_backup"`,
	)
}

func TestAdditionalReadReplicaCoverage(t *testing.T) {
	root := moduleRoot(t)
	vars := readFile(t, filepath.Join(root, "variables.tf"))
	main := readFile(t, filepath.Join(root, "main.tf"))
	outputs := readFile(t, filepath.Join(root, "outputs.tf"))

	requireContains(t, vars, `variable "additional_read_replicas"`)
	requireContains(t, main,
		`resource "azurerm_postgresql_flexible_server" "additional_replica"`,
		`resource "azurerm_private_endpoint" "additional_replica_postgresql"`,
		`data "azurerm_monitor_diagnostic_categories" "additional_replica"`,
		`resource "azurerm_monitor_diagnostic_setting" "additional_replica"`,
	)
	requireContains(t, outputs, `output "additional_read_replica_ids"`)
}

func TestMonitoringCoverage(t *testing.T) {
	root := moduleRoot(t)
	vars := readFile(t, filepath.Join(root, "variables.tf"))
	main := readFile(t, filepath.Join(root, "main.tf"))
	outputs := readFile(t, filepath.Join(root, "outputs.tf"))

	requireContains(t, vars,
		`variable "create_log_analytics_workspace"`,
		`variable "enable_primary_diagnostics"`,
		`variable "enable_dr_diagnostics"`,
		`variable "metric_alerts"`,
		`variable "create_monitor_action_group"`,
		`variable "action_group_email_receivers"`,
		`variable "create_monitor_workbook"`,
	)

	requireContains(t, main,
		`resource "azurerm_log_analytics_workspace" "postgresql"`,
		`resource "azurerm_monitor_diagnostic_setting" "primary"`,
		`resource "azurerm_monitor_diagnostic_setting" "dr"`,
		`resource "azurerm_monitor_metric_alert" "postgresql"`,
		`resource "azurerm_monitor_action_group" "postgresql"`,
		`resource "azurerm_application_insights_workbook" "postgresql"`,
	)
	requireContains(t, vars, `contains(["primary", "dr"], alert.target)`)

	requireContains(t, outputs,
		`output "log_analytics_workspace_id"`,
		`output "monitor_action_group_id"`,
		`output "monitor_workbook_id"`,
	)
}

func TestRegionalCMKCoverage(t *testing.T) {
	root := moduleRoot(t)
	vars := readFile(t, filepath.Join(root, "variables.tf"))
	main := readFile(t, filepath.Join(root, "main.tf"))
	outputs := readFile(t, filepath.Join(root, "outputs.tf"))

	requireContains(t, vars,
		`variable "create_primary_key_vault"`,
		`variable "existing_primary_key_vault_id"`,
		`variable "create_dr_key_vault"`,
		`variable "existing_dr_key_vault_id"`,
		`variable "create_primary_key_vault_key"`,
		`variable "existing_primary_key_vault_key_id"`,
		`variable "create_dr_key_vault_key"`,
		`variable "existing_dr_key_vault_key_id"`,
		`variable "create_primary_cmk_role_assignment"`,
		`variable "create_dr_cmk_role_assignment"`,
	)

	requireContains(t, main,
		`resource "azurerm_key_vault" "primary_postgresql"`,
		`resource "azurerm_key_vault" "dr_postgresql"`,
		`resource "azurerm_key_vault_key" "primary_postgresql"`,
		`resource "azurerm_key_vault_key" "dr_postgresql"`,
		`resource "azurerm_role_assignment" "primary_cmk_crypto"`,
		`resource "azurerm_role_assignment" "dr_cmk_crypto"`,
	)

	requireContains(t, outputs,
		`output "primary_key_vault_id"`,
		`output "dr_key_vault_id"`,
		`output "primary_key_vault_key_id"`,
		`output "dr_key_vault_key_id"`,
		`output "primary_effective_cmk_key_id"`,
		`output "dr_effective_cmk_key_id"`,
	)
}

func TestPortalManageableFeatureCoverage(t *testing.T) {
	root := moduleRoot(t)
	vars := readFile(t, filepath.Join(root, "variables.tf"))
	main := readFile(t, filepath.Join(root, "main.tf"))
	outputs := readFile(t, filepath.Join(root, "outputs.tf"))

	requireContains(t, vars,
		`variable "deployment_type"`,
		`variable "query_store"`,
		`variable "autonomous_tuning"`,
		`variable "logging"`,
		`variable "defender_subscription_plan_tier"`,
		`variable "primary_defender_threat_protection_state"`,
		`variable "create_backup_vault"`,
		`variable "create_backup_policy"`,
		`variable "create_ltr_backup_instance"`,
		`variable "create_monitor_action_group"`,
		`variable "create_monitor_workbook"`,
		`variable "advisor_suppressions"`,
		`variable "create_primary_key_vault"`,
		`variable "create_dr_key_vault"`,
		`variable "create_primary_key_vault_key"`,
		`variable "create_dr_key_vault_key"`,
	)

	requireContains(t, main,
		`resource "azurerm_security_center_subscription_pricing"`,
		`Microsoft.DBforPostgreSQL/flexibleServers/advancedThreatProtectionSettings@2025-08-01`,
		`resource "azurerm_data_protection_backup_vault"`,
		`resource "azurerm_data_protection_backup_policy_postgresql_flexible_server"`,
		`resource "azurerm_data_protection_backup_instance_postgresql_flexible_server"`,
		`resource "azurerm_monitor_action_group"`,
		`resource "azurerm_application_insights_workbook"`,
		`resource "azurerm_advisor_suppression"`,
		`resource "azurerm_key_vault"`,
		`resource "azurerm_key_vault_key"`,
		`pg_qs.query_capture_mode`,
		`index_tuning.mode`,
		`log_connections`,
	)

	requireContains(t, outputs,
		`output "deployment_type"`,
		`output "backup_vault_id"`,
		`output "backup_policy_id"`,
		`output "ltr_backup_instance_id"`,
		`output "monitor_action_group_id"`,
		`output "monitor_workbook_id"`,
		`output "primary_key_vault_id"`,
		`output "dr_key_vault_id"`,
		`output "primary_key_vault_key_id"`,
		`output "dr_key_vault_key_id"`,
		`output "defender_management"`,
	)
}

func TestMasterSampleCoversVariablesAndIsSafeByDefault(t *testing.T) {
	root := moduleRoot(t)
	varsContent := readFile(t, filepath.Join(root, "variables.tf"))
	sample := readFile(t, masterSamplePath(t))

	declared := variableNames(varsContent)
	assignments := topLevelAssignments(sample)

	counts := map[string]int{}
	for _, name := range assignments {
		counts[name]++
		if !declared[name] {
			t.Errorf("master sample references undeclared top-level variable %s", name)
		}
	}

	for name := range declared {
		if name == "administrator_password" {
			continue
		}
		if counts[name] == 0 {
			t.Errorf("master sample does not represent variable %s", name)
		}
		if counts[name] > 1 {
			t.Errorf("master sample contains duplicate active assignment for %s", name)
		}
	}

	if regexp.MustCompile(`(?m)^\s*administrator_password\s*=`).MatchString(sample) {
		t.Fatalf("administrator_password must not be actively assigned in master sample")
	}

	if !strings.Contains(sample, `TF_VAR_administrator_password`) {
		t.Fatalf("master sample must document TF_VAR_administrator_password")
	}

	reCreateTrue := regexp.MustCompile(`(?m)^\s*create_[A-Za-z0-9_]+\s*=\s*true\s*$`)
	if reCreateTrue.MatchString(sample) {
		t.Fatalf("universal master sample must remain safe-by-default; found active create_* = true")
	}

	requireContains(t, sample,
		`subscription_id = "<REQUIRED-SUBSCRIPTION-ID>"`,
		`primary_location = "USGov Virginia"`,
		`dr_location = "USGov Texas"`,
		`deployment_type = "server"`,
		`privatelink.postgres.database.usgovcloudapi.net`,
		`privatelink.vaultcore.usgovcloudapi.net`,
		`CREATE NEW`,
		`USE EXISTING`,
		`NOT CONFIGURED`,
	)
}

func TestMasterSampleDocumentsWorkingVirginiaBaseline(t *testing.T) {
	sample := readFile(t, masterSamplePath(t))
	requireContains(t, sample,
		`VALIDATED AGAINST WORKING VIRGINIA BASELINE`,
		`Two same-region read replicas`,
		`Seven Primary Azure Monitor metric alerts`,
		`One default Azure Monitor Action Group`,
		`primary_database_unavailable`,
		`primary_high_cpu`,
		`primary_cpu_critical`,
		`primary_high_memory`,
		`primary_memory_critical`,
		`primary_high_storage_usage`,
		`primary_storage_critical`,
	)
}

func TestScenarioCoverageAndAzureGuardrails(t *testing.T) {
	root := moduleRoot(t)
	vars := readFile(t, filepath.Join(root, "variables.tf"))
	main := readFile(t, filepath.Join(root, "main.tf"))
	runbook := readFile(t, filepath.Join(root, "docs", "DR_RUNBOOK.md"))
	matrix := readFile(t, filepath.Join(root, "docs", "SCENARIO_MATRIX.md"))

	requireContains(t, vars,
		`variable "create_secondary_server"`,
		`variable "primary_zone"`,
		`variable "dr_zone"`,
		`variable "primary_high_availability"`,
		`variable "dr_high_availability"`,
		`check "usgov_texas_zone_redundant_ha"`,
		`check "secondary_ha_rules"`,
	)

	requireContains(t, main,
		`resource "azurerm_postgresql_flexible_server" "secondary"`,
		`resource "azurerm_postgresql_flexible_server" "dr_replica"`,
		`create_mode         = "Replica"`,
	)

	requireContains(t, runbook,
		`multi-region Active/Passive topology`,
		`dr-failover.ps1`,
		`dr-failback.ps1`,
		`Standalone`,
		`Terraform Reconciliation After DR`,
	)

	requireContains(t, matrix,
		`Active / Passive Cross-Region DR`,
		`Native multi-writer Active/Active`,
		`Planned SwitchOver`,
		`Forced SwitchOver`,
		`Additional read replicas`,
	)
}

func TestNoLegacyVariableReferences(t *testing.T) {
	root := moduleRoot(t)
	files := []string{"main.tf", "outputs.tf", "variables.tf"}
	forbidden := []string{
		"var.create_resource_groups",
		"var.create_networking",
		"var.create_private_endpoints",
		"var.create_private_dns_vnet_links",
		"var.log_analytics_workspace_id",
		"var.manage_databases",
		"var.create_key_vault",
		"var.existing_key_vault_id",
		"var.create_key_vault_key",
		"var.existing_key_vault_key_id",
	}

	for _, file := range files {
		content := readFile(t, filepath.Join(root, file))
		for _, value := range forbidden {
			if strings.Contains(content, value) {
				t.Errorf("legacy reference %q found in %s", value, file)
			}
		}
	}
}

func TestEveryVarReferenceIsDeclared(t *testing.T) {
	root := moduleRoot(t)
	varsContent := readFile(t, filepath.Join(root, "variables.tf"))
	declared := variableNames(varsContent)

	refs := map[string]bool{}
	for _, file := range []string{"main.tf", "outputs.tf", "versions.tf", "variables.tf"} {
		content := readFile(t, filepath.Join(root, file))
		for ref := range varReferences(content) {
			refs[ref] = true
		}
	}

	missing := []string{}
	for ref := range refs {
		if !declared[ref] {
			missing = append(missing, ref)
		}
	}
	sort.Strings(missing)
	if len(missing) > 0 {
		t.Fatalf("undeclared var.* references: %v", missing)
	}
}

func TestSampleTopLevelVariablesAreDeclared(t *testing.T) {
	root := moduleRoot(t)
	vars := readFile(t, filepath.Join(root, "variables.tf"))
	declared := variableNames(vars)

	files, err := filepath.Glob(filepath.Join(root, "sample", "*.tfvars"))
	if err != nil {
		t.Fatal(err)
	}
	for _, file := range files {
		content := readFile(t, file)
		for _, name := range topLevelAssignments(content) {
			if !declared[name] {
				t.Errorf("sample %s references undeclared top-level variable %s", filepath.Base(file), name)
			}
		}
	}
}

func TestSecondaryOnlySharedCreationProperties(t *testing.T) {
	vars := readFile(t, filepath.Join(moduleRoot(t), "variables.tf"))
	for _, want := range []string{
		"var.create_primary_server || var.create_secondary_server",
		"var.authentication == null && var.elastic_cluster == null",
	} {
		if !strings.Contains(vars, want) {
			t.Fatalf("secondary-only creation guard is missing %q", want)
		}
	}
}

func TestPostgreSQLExistingPrivateEndpointInterfaceIsNotOverstated(t *testing.T) {
	root := moduleRoot(t)
	vars := readFile(t, filepath.Join(root, "variables.tf"))
	main := readFile(t, filepath.Join(root, "main.tf"))
	sample := readFile(t, masterSamplePath(t))

	requireContains(t, vars,
		`variable "existing_primary_private_endpoint_id"`,
		`variable "existing_dr_private_endpoint_id"`,
	)

	// Current main.tf does not consume these IDs. Keep the master template honest.
	if strings.Contains(main, "var.existing_primary_private_endpoint_id") ||
		strings.Contains(main, "var.existing_dr_private_endpoint_id") {
		t.Log("existing PostgreSQL Private Endpoint lookup/use has been implemented; update the master-template caveat when appropriate")
	} else {
		requireContains(t, sample,
			`existing_primary_private_endpoint_id and existing_dr_private_endpoint_id`,
			`Keep those two values null`,
		)
	}
}

func TestTerraformFmtValidate(t *testing.T) {
	if os.Getenv("RUN_TERRAFORM_CLI_TESTS") != "true" {
		t.Skip("set RUN_TERRAFORM_CLI_TESTS=true to run terraform fmt/init/validate")
	}

	terraform, err := exec.LookPath("terraform")
	if err != nil {
		t.Skip("terraform executable is not installed")
	}

	root := moduleRoot(t)
	commands := [][]string{
		{"fmt", "-check", "-recursive"},
		{"init", "-backend=false", "-input=false"},
		{"validate", "-no-color"},
	}

	for _, args := range commands {
		cmd := exec.Command(terraform, args...)
		cmd.Dir = root
		output, err := cmd.CombinedOutput()
		if err != nil {
			t.Fatalf("terraform %s failed: %v\n%s", strings.Join(args, " "), err, string(output))
		}
	}
}
