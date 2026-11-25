#!/usr/bin/env bash
# Runs Terraform for this stack in one environment.
# Usage: scripts/tf.sh <dev|test|prod> <init|plan|apply|destroy|output|...> [args]
# State lives in the Landing Zone state bucket named in environments/<env>/backend.hcl (git-ignored).
# environments/common.tfvars (shared posture) is loaded before environments/<env>/terraform.tfvars (identity).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV="${1:?env: dev|test|prod}"
CMD="${2:?command}"
shift 2
case "$ENV" in dev|test|prod) ;; *) echo "env must be dev, test or prod" >&2; exit 2 ;; esac

TF="${TF_BIN:-terraform}"
ENVDIR="$ROOT/environments/$ENV"
KEY="aws-devsecops-pipeline/$ENV.tfstate"
[ -f "$ENVDIR/backend.hcl" ] || { echo "missing $ENVDIR/backend.hcl (copy backend.hcl.example)" >&2; exit 2; }
[ -f "$ENVDIR/terraform.tfvars" ] || { echo "missing $ENVDIR/terraform.tfvars (copy terraform.tfvars.example)" >&2; exit 2; }

case "$CMD" in
  init)
    exec "$TF" -chdir="$ROOT" init -reconfigure -backend-config="$ENVDIR/backend.hcl" \
      -backend-config="key=$KEY" "$@" ;;
  plan|apply|destroy|import|refresh)
    exec "$TF" -chdir="$ROOT" "$CMD" \
      -var-file="$ROOT/environments/common.tfvars" -var-file="$ENVDIR/terraform.tfvars" "$@" ;;
  *)
    exec "$TF" -chdir="$ROOT" "$CMD" "$@" ;;
esac
