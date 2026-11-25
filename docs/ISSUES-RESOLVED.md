# Issues resolved in this refactor

Scope: bring the existing repository in line with the Landing Zone and the portfolio standards. Only the affected services and parts changed; the pipeline stages, buildspecs, CodeBuild projects, notifications and runbooks keep their design.

| # | Issue | Resolution |
|---|---|---|
| 1 | The Landing Zone state location was hardcoded as a placeholder and read with no contract check | `landing_zone.tf`: variables for the state location, `contract_schema_version` precondition |
| 2 | Code referenced Landing Zone outputs that do not exist (`intra_subnet_ids`, per-tier subnet lists) and declared the same data sources twice | Removed `data.tf`; only the outputs the stack uses are read |
| 3 | A required, sensitive `kms_key_arn` input pointed at a key the Ireland Region cannot use | Removed; AWS-managed encryption (ADR-3) |
| 4 | The stack created ECR repositories and the account-wide registry scanning configuration, duplicating the Landing Zone | Consumes `ecr_repository_urls` (ADR-2); the pipeline role is scoped to that repository |
| 5 | The GitHub source connection cannot exist in af-south-1 and CodeArtifact is not offered there | Pipeline and CodeArtifact run in eu-west-1 through one `aws.ireland` alias (ADR-1); unused second alias removed |
| 6 | Module inputs did not line up (replication settings required but never supplied, undeclared `region`, undeclared `organization_name` and `environment`) | Module interfaces aligned; replication removed |
| 7 | S3 event notifications targeted SNS topics that were never created | Removed |
| 8 | Buildspec comments and the README claimed a Security Hub import that was never configured | Claims removed; reports are build artifacts (ADR-8); unused IAM permissions removed |
| 9 | `CloudWatchLogsFullAccess` attached to the build role | Replaced by the existing scoped log statement |
| 10 | ECR login used the pipeline Region for a registry in another Region | `ECR_REGION` and `WORKLOAD_REGION` environment variables |
| 11 | Provider pins were Terraform 1.6 and AWS provider 5.x | Terraform >= 1.10, AWS provider >= 6.27 and < 7.0, `use_lockfile` state locking |
| 12 | Per-environment backend files with placeholder buckets | Partial backend, `scripts/tf.sh`, shared `environments/common.tfvars` |
| 13 | A script created a state bucket | Removed: state buckets belong to the Landing Zone |
| 14 | Runbooks and scripts used af-south-1 for pipeline commands | Updated to eu-west-1; ECR commands use af-south-1 |
| 15 | No CI in the repository though the README referenced it | `.github/workflows/ci.yml` and `security.yml` |
