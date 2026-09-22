package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformPostgreSQLFlexibleServer(t *testing.T) {

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		// Terraform module location
		TerraformDir: "../",

		// Use existing sample tfvars
		VarFiles: []string{
			"sample/sample.tfvars",
		},
	})

	// Cleanup after test
	defer terraform.Destroy(t, terraformOptions)

	// terraform init + terraform apply
	terraform.InitAndApply(t, terraformOptions)

	// Read Terraform output
	postgresqlServerID := terraform.Output(
		t,
		terraformOptions,
		"primary_server_id",
	)

	// Validate resource was created
	assert.NotEmpty(
		t,
		postgresqlServerID,
		"PostgreSQL Flexible Server ID should not be empty",
	)
}