#!/usr/bin/env bash
# ============================================================
# scripts/setup-github-connection.sh
# Create a CodeConnections connection for GitHub integration
# ============================================================
# NOTE: After creation, you MUST manually complete the
# OAuth handshake in the AWS Console before using the connection.
#
# Usage: REGION=eu-west-1 bash scripts/setup-github-connection.sh

set -euo pipefail
: "${REGION:=${AWS_DEFAULT_REGION:-eu-west-1}}"
: "${CONNECTION_NAME:=github-enterprise-connection}"

echo "Creating CodeConnections connection: ${CONNECTION_NAME}"
CONNECTION_ARN=$(aws codeconnections create-connection \
  --provider-type GitHub \
  --connection-name "${CONNECTION_NAME}" \
  --region "${REGION}" \
  --query 'ConnectionArn' --output text)

echo "[✓] Connection ARN: ${CONNECTION_ARN}"
echo ""
echo "IMPORTANT: Complete OAuth in AWS Console:"
echo "  https://console.aws.amazon.com/codesuite/settings/connections?region=${REGION}"
echo ""
echo "After OAuth approval, add to terraform.tfvars:"
echo "  github_connection_arn = \"${CONNECTION_ARN}\""
