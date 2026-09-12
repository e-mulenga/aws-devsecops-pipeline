#!/usr/bin/env bash
# ============================================================
# validation/validate-pipeline.sh
# Post-deployment validation for the DevSecOps Pipeline
# ============================================================
# Usage: ENV=prod AWS_REGION=af-south-1 ORG=acme bash validation/validate-pipeline.sh

set -euo pipefail
: "${ENV:?Required: ENV}"; : "${ORG:?Required: ORG}"
: "${AWS_REGION:=${AWS_DEFAULT_REGION:-af-south-1}}"

PASS=0; FAIL=0; WARN=0
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; NC='\033[0m'
pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; ((WARN++)); }

echo "============================================"
echo " DevSecOps Pipeline Validation"
echo " Org: ${ORG} | Env: ${ENV} | Region: ${AWS_REGION}"
echo "============================================"

PIPELINE_NAME="${ORG}-${ENV}-devsecops-pipeline"

# 1. Pipeline exists
echo -e "\n--- CodePipeline ---"
STATUS=$(aws codepipeline get-pipeline --name "${PIPELINE_NAME}" --query 'pipeline.name' --output text --region "${AWS_REGION}" 2>/dev/null || echo "NOT_FOUND")
[[ "${STATUS}" != "NOT_FOUND" ]] && pass "Pipeline exists: ${PIPELINE_NAME}" || fail "Pipeline NOT found: ${PIPELINE_NAME}"

# 2. Pipeline stages
STAGE_COUNT=$(aws codepipeline get-pipeline --name "${PIPELINE_NAME}" --query 'length(pipeline.stages)' --output text --region "${AWS_REGION}" 2>/dev/null || echo 0)
[[ "${STAGE_COUNT}" -ge 8 ]] && pass "Pipeline has ${STAGE_COUNT} stages (≥8 required)" || fail "Pipeline has only ${STAGE_COUNT} stages — expected ≥8"

# 3. ECR repositories
echo -e "\n--- ECR ---"
ECR_COUNT=$(aws ecr describe-repositories --query "length(repositories[?starts_with(repositoryName, '${ORG}-${ENV}')])" --output text --region "${AWS_REGION}" 2>/dev/null || echo 0)
[[ "${ECR_COUNT}" -ge 1 ]] && pass "ECR repositories: ${ECR_COUNT}" || fail "No ECR repositories found with prefix '${ORG}-${ENV}'"

# ECR scanning enabled
SCAN_STATUS=$(aws ecr describe-registry --query 'scanningConfiguration.scanType' --output text --region "${AWS_REGION}" 2>/dev/null || echo "NONE")
[[ "${SCAN_STATUS}" == "ENHANCED" ]] && pass "ECR enhanced scanning (Inspector) enabled" || warn "ECR enhanced scanning not confirmed — check Inspector v2"

# 4. CodeBuild projects
echo -e "\n--- CodeBuild ---"
EXPECTED_PROJECTS=("secret-scan" "sast" "build" "container-scan" "iac-scan" "sbom" "integration-test" "dast" "deploy-dev" "deploy-test" "deploy-prod")
for STAGE in "${EXPECTED_PROJECTS[@]}"; do
  PROJECT="${ORG}-${ENV}-${STAGE}"
  CB_STATUS=$(aws codebuild batch-get-projects --names "${PROJECT}" --query 'projects[0].name' --output text --region "${AWS_REGION}" 2>/dev/null || echo "NOT_FOUND")
  [[ "${CB_STATUS}" != "NOT_FOUND" && "${CB_STATUS}" != "None" ]] && pass "CodeBuild project: ${PROJECT}" || fail "CodeBuild project NOT found: ${PROJECT}"
done

# 5. Artifact S3 bucket
echo -e "\n--- Artifact Store ---"
ARTIFACT_BUCKET="${ORG}-pipeline-artifacts-${ENV}"
BUCKET_EXISTS=$(aws s3api head-bucket --bucket "${ARTIFACT_BUCKET}" 2>/dev/null && echo "YES" || echo "NO")
[[ "${BUCKET_EXISTS}" == "YES" ]] && pass "Artifact bucket: ${ARTIFACT_BUCKET}" || fail "Artifact bucket NOT found: ${ARTIFACT_BUCKET}"

if [[ "${BUCKET_EXISTS}" == "YES" ]]; then
  VERSIONING=$(aws s3api get-bucket-versioning --bucket "${ARTIFACT_BUCKET}" --query 'Status' --output text 2>/dev/null || echo "NONE")
  [[ "${VERSIONING}" == "Enabled" ]] && pass "Artifact bucket versioning: enabled" || fail "Artifact bucket versioning NOT enabled"
  ENCRYPTION=$(aws s3api get-bucket-encryption --bucket "${ARTIFACT_BUCKET}" --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault.SSEAlgorithm' --output text 2>/dev/null || echo "NONE")
  [[ "${ENCRYPTION}" == "aws:kms" ]] && pass "Artifact bucket encryption: aws:kms" || fail "Artifact bucket NOT encrypted with KMS"
fi

# 6. SNS Notification topics
echo -e "\n--- Notifications ---"
ALERT_TOPIC=$(aws sns list-topics --query "Topics[?contains(TopicArn, '${ORG}-${ENV}-pipeline-alerts')]" --output text --region "${AWS_REGION}" 2>/dev/null || echo "")
[[ -n "${ALERT_TOPIC}" ]] && pass "Alert SNS topic exists" || fail "Alert SNS topic NOT found"
APPROVAL_TOPIC=$(aws sns list-topics --query "Topics[?contains(TopicArn, '${ORG}-${ENV}-pipeline-approval')]" --output text --region "${AWS_REGION}" 2>/dev/null || echo "")
[[ -n "${APPROVAL_TOPIC}" ]] && pass "Approval SNS topic exists" || fail "Approval SNS topic NOT found"

# 7. CloudWatch dashboard
echo -e "\n--- Monitoring ---"
DASHBOARD=$(aws cloudwatch describe-alarms --alarm-name-prefix "${ORG}-${ENV}-pipeline" --query 'MetricAlarms[0].AlarmName' --output text --region "${AWS_REGION}" 2>/dev/null || echo "NONE")
[[ "${DASHBOARD}" != "NONE" && -n "${DASHBOARD}" ]] && pass "CloudWatch alarm configured: ${DASHBOARD}" || warn "No CloudWatch pipeline alarms found"

# 8. CodeArtifact domain
echo -e "\n--- CodeArtifact ---"
CA_DOMAIN=$(aws codeartifact list-domains --query "domains[?contains(name, '${ORG}-${ENV}')].name" --output text --region "${AWS_REGION}" 2>/dev/null || echo "")
[[ -n "${CA_DOMAIN}" ]] && pass "CodeArtifact domain: ${CA_DOMAIN}" || warn "No CodeArtifact domain found (may be disabled)"

# Summary
echo ""
echo "============================================"
echo " PASS: ${PASS}  WARN: ${WARN}  FAIL: ${FAIL}"
echo "============================================"
[[ "${FAIL}" -gt 0 ]] && exit 1 || exit 0
