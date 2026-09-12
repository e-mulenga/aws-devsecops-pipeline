# Pipeline Failure Runbook
## AWS DevSecOps Pipeline

**Portfolio:** Enterprise Cloud Platform — Position 3 of 6

---

## Quick Reference

| Failure Type | First Action | Escalation |
|---|---|---|
| Source stage | Check GitHub connection status | Re-auth CodeStar connection |
| Secret scan blocked | Rotate the exposed credential immediately | Security team P1 |
| SAST blocked | Fix code finding or raise waiver PR | Security Architect review |
| Build failure | Check CodeBuild logs for compile/test error | Dev team |
| Container scan blocked | Patch base image or dependency | Security + Dev team |
| Approval timeout | Re-notify approvers | Platform Engineering |
| Deploy failure | Check target account role + kubeconfig | Platform + Ops |

---

## Runbook 1: Pipeline Won't Start

```bash
# Check CodeStar connection status
aws codestar-connections list-connections \
  --region af-south-1 \
  --query 'Connections[*].{Name:ConnectionName,Status:ConnectionStatus}'

# If PENDING: complete OAuth in console
# https://console.aws.amazon.com/codesuite/settings/connections

# Check pipeline execution history
aws codepipeline list-pipeline-executions \
  --pipeline-name "${ORG}-${ENV}-devsecops-pipeline" \
  --max-results 5 \
  --region af-south-1 \
  --query 'pipelineExecutionSummaries[*].{Status:status,Trigger:trigger,StartTime:startTime}'
```

---

## Runbook 2: Secret Scan Blocked (gitleaks)

> **This is a P1 security event.** Treat as credential compromise.

```bash
# 1. Identify the secret — check CodeBuild logs
aws logs get-log-events \
  --log-group-name "/aws/codebuild/${ORG}-${ENV}-secret-scan" \
  --log-stream-name "$(aws logs describe-log-streams \
      --log-group-name /aws/codebuild/${ORG}-${ENV}-secret-scan \
      --order-by LastEventTime --descending \
      --query 'logStreams[0].logStreamName' --output text)" \
  --region af-south-1 \
  --query 'events[*].message' --output text | grep -i "secret\|leak\|found"

# 2. Immediately rotate the exposed credential
# 3. Purge from git history using git-filter-repo
git filter-repo --path <file> --invert-paths
git push --force-with-lease

# 4. Notify Security team — log incident in Jira
# 5. Re-run pipeline after credential rotation confirmed
```

---

## Runbook 3: SAST Gate Blocked

```bash
# View full Semgrep findings
aws logs get-log-events \
  --log-group-name "/aws/codebuild/${ORG}-${ENV}-sast" \
  --log-stream-name "$(aws logs describe-log-streams \
      --log-group-name /aws/codebuild/${ORG}-${ENV}-sast \
      --order-by LastEventTime --descending \
      --query 'logStreams[0].logStreamName' --output text)" \
  --region af-south-1 --query 'events[*].message' --output text

# Options:
# A) Fix the finding in code (preferred)
# B) Add semgrep nosemgrep comment with justification
# C) Raise a security waiver PR — requires Security Architect approval
# D) Change SAST_FAILURE_ACTION to WARN (requires CAB for prod)
```

---

## Runbook 4: Container Scan Blocked

```bash
# Get the vulnerable image URI
IMAGE_URI=$(aws codepipeline get-pipeline-state \
  --name "${ORG}-${ENV}-devsecops-pipeline" \
  --query 'stageStates[?stageName==`Build`].actionStates[0].currentRevision.revisionSummary' \
  --output text --region af-south-1)

# View Trivy findings
aws logs get-log-events \
  --log-group-name "/aws/codebuild/${ORG}-${ENV}-container-scan" \
  --log-stream-name "$(aws logs describe-log-streams \
      --log-group-name /aws/codebuild/${ORG}-${ENV}-container-scan \
      --order-by LastEventTime --descending \
      --query 'logStreams[0].logStreamName' --output text)" \
  --region af-south-1 --query 'events[*].message' --output text | grep -A5 "CRITICAL\|HIGH"

# Resolution options:
# A) Update base image to patched version (preferred)
#    FROM node:20-alpine  →  FROM node:20.11-alpine3.19
# B) Update vulnerable package: npm audit fix / pip install --upgrade <pkg>
# C) Add .trivyignore with CVE justification (Security Architect approval)
```

---

## Runbook 5: Deploy Stage Fails

```bash
ACCOUNT_ID="<target account ID>"
ENV_TARGET="dev"  # dev | test | prod

# Verify cross-account role exists in target
aws sts assume-role \
  --role-arn "arn:aws:iam::${ACCOUNT_ID}:role/${ORG}-pipeline-deploy-role" \
  --role-session-name "manual-debug" \
  --query 'Credentials.AccessKeyId' --output text

# If role doesn't exist: apply policies/iam/pipeline-deployment-role.json
# in the target account manually

# Check EKS cluster status (if using EKS)
aws eks describe-cluster \
  --name "${ORG}-${ENV_TARGET}-cluster" \
  --region af-south-1 \
  --query 'cluster.status'

# Manual rollback — revert to previous image tag
aws codepipeline stop-pipeline-execution \
  --pipeline-name "${ORG}-${ENV}-devsecops-pipeline" \
  --pipeline-execution-id <EXECUTION_ID> \
  --abandon \
  --reason "Manual rollback initiated" \
  --region af-south-1
```

---

## Runbook 6: Manual Approval Timeout

```bash
# Re-send approval notification
aws codepipeline put-approval-result \
  --pipeline-name "${ORG}-${ENV}-devsecops-pipeline" \
  --stage-name "ApproveTest" \
  --action-name "ApproveDeployToTest" \
  --result '{"summary":"Re-approved after timeout","status":"Approved"}' \
  --token <TOKEN_FROM_SNS_NOTIFICATION> \
  --region af-south-1

# Or abandon and re-run the pipeline
aws codepipeline retry-stage-execution \
  --pipeline-name "${ORG}-${ENV}-devsecops-pipeline" \
  --stage-name "ApproveTest" \
  --pipeline-execution-id <EXECUTION_ID> \
  --retry-mode FAILED_ACTIONS \
  --region af-south-1
```

---

*Owner: Platform Engineering | Review: Quarterly*
