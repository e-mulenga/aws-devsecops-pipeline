# ============================================================
# Shared posture: applied to dev, test AND prod by scripts/tf.sh. Only identity differs per environment.
# Cost rule: CodeBuild bills per build minute (no idle cost), CodePipeline per active pipeline, CodeArtifact per GB stored and
# per request. Guards: SMALL compute for light stages, 30-day artifact expiry, 90-day log retention, ARM-free defaults off.
# ============================================================

primary_region = "af-south-1"
ireland_region = "eu-west-1"

# Container registry: owned by the Landing Zone (ecr_repository_urls output)
ecr_repository_key = "shared-devsecops"

# Build
build_compute_type    = "BUILD_GENERAL1_SMALL"
build_image           = "aws/codebuild/standard:7.0"
build_timeout_minutes = 30

# Security gates
sast_enabled                      = true
dast_enabled                      = true
sbom_enabled                      = true
iac_scan_enabled                  = true
dependency_scan_enabled           = true
secret_scan_enabled               = true
sast_failure_action               = "BLOCK"
container_scan_severity_threshold = "HIGH"

# Approvals
require_test_approval = true
require_prod_approval = true

# Package registry (eu-west-1; not offered in af-south-1)
codeartifact_enabled = true

# Retention and alarms
artifact_retention_days           = 30
log_retention_days                = 365
enable_alarms                     = true
pipeline_alarm_threshold_failures = 3
