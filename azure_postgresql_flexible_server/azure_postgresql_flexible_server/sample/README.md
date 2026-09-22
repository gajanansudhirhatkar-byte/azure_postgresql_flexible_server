# sample.tfvars

This module intentionally uses one example input file: `sample.tfvars`.

The active values deploy a standard PostgreSQL Flexible Server in US Gov Virginia only. Modify the same file for secondary-only, Active/Passive, zone/HA, existing-resource, or Elastic Cluster scenarios.

Use `create_* = true` to create a resource. Use `create_* = false` with the corresponding existing resource ID/name to reference an existing resource. Optional features are configured only when their inputs are populated.
