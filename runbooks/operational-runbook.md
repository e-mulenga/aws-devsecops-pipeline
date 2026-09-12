# Operational Runbook
## AWS DevSecOps Pipeline

**Portfolio:** Enterprise Cloud Platform — Position 3 of 6
**Owner:** Platform Engineering

---

## Section 1: Day-2 Operations

### 1.1 Trigger a Manual Pipeline Run

```bash
# Start pipeline execution
aws codepipeline start-pipeline-execution \
  --name "${ORG}-${ENV}-devsecops-pipeline" \
  --region af-south-1 \
  --query 'pipelineExecutionId' --output text

# Watch execution status
watch -n 10 "aws codepipeline get-pipeline-state \
  --name ${ORG}-${ENV}-devsecops-pipeline \
  --region af-south-1 \
  --query 'stageStates[*].{Stage:stageName,Status:latestExecution.status}' \
  --output table"
```

### 1.2 Update a Buildspec Without Redeploying Infrastructure

```bash
# Buildspecs are read from S3 artifact store at runtime
# Simply commit the updated buildspec to main
git add buildspecs/buildspec-sast.yml
git commit -m "security(sast): add CWE-top-25 ruleset to Semgrep scan"
git push origin main
# Pipeline picks up the new buildspec on next execution automatically
```

### 1.3 Add a New ECR Repository

```bash
# 1. Add to variables.tfvars
echo 'ecr_repository_names = ["app", "sidecar", "new-service"]' >> environments/prod/terraform.tfvars

# 2. Apply (ECR module uses for_each — no disruption to existing repos)
terraform apply \
  -var-file="environments/prod/terraform.tfvars" \
  -target=module.ecr \
  --auto-approve

# 3. Verify
aws ecr describe-repositories \
  --query "repositories[?starts_with(repositoryName,'${ORG}-${ENV}')].repositoryName" \
  --output table --region af-south-1
```

### 1.4 Rotate the GitHub Connection

```bash
# 1. Create a new connection
bash scripts/setup-github-connection.sh

# 2. Complete OAuth in console

# 3. Update terraform.tfvars with new ARN
# github_connection_arn = "arn:aws:codestar-connections:..."

# 4. Apply
terraform apply -var-file="environments/prod/terraform.tfvars" \
  -target=module.codepipeline

# 5. Delete old connection
aws codestar-connections delete-connection \
  --connection-arn <OLD_ARN> --region af-south-1
```

---

## Section 2: Security Gate Management

### 2.1 View Security Findings by Stage

```bash
# Secret scan findings
aws codebuild batch-get-builds \
  --ids $(aws codebuild list-builds-for-project \
      --project-name "${ORG}-${ENV}-secret-scan" \
      --query 'ids[0]' --output text) \
  --query 'builds[0].phases[*].{Phase:phaseType,Status:phaseStatus,Duration:durationInSeconds}' \
  --output table --region af-south-1

# Latest SAST log tail
aws logs tail "/aws/codebuild/${ORG}-${ENV}-sast" \
  --since 1h --format short --region af-south-1
```

### 2.2 Approve a Security Waiver

Security waivers allow a known finding to be suppressed with documented justification.

```bash
# For Semgrep (SAST): add inline comment
# python
# nosemgrep: python.django.security.audit.xss.direct-use-of-jinja2 -- Reviewed: XSS mitigated by CSP headers
result = render_template(template)

# For Trivy (container scan): add .trivyignore
cat >> .trivyignore << EOF
# CVE-2023-XXXXX — upstream patch pending; mitigated by WAF rule XXXXX
# Approved by: security@company.com | Date: 2024-01-15 | Expires: 2024-04-15
CVE-2023-XXXXX
EOF

# For tfsec (IaC): add inline ignore
# tfsec:ignore:aws-s3-enable-bucket-logging -- Access logging to dedicated bucket handled by caller

# IMPORTANT: All waivers must be reviewed in the quarterly security posture review
```

---

## Section 3: Monitoring & Alerts

### 3.1 Check Pipeline Health

```bash
# Last 24h pipeline executions
aws codepipeline list-pipeline-executions \
  --pipeline-name "${ORG}-${ENV}-devsecops-pipeline" \
  --max-results 10 \
  --query 'pipelineExecutionSummaries[*].{Status:status,Start:startTime,Trigger:trigger.triggerType}' \
  --output table --region af-south-1

# CloudWatch dashboard URL
echo "https://console.aws.amazon.com/cloudwatch/home?region=af-south-1#dashboards:name=${ORG}-${ENV}-devsecops-pipeline"
```

### 3.2 Test SNS Notification Delivery

```bash
TOPIC_ARN=$(aws sns list-topics \
  --query "Topics[?contains(TopicArn,'${ORG}-${ENV}-pipeline-alerts')].TopicArn" \
  --output text --region af-south-1)

aws sns publish \
  --topic-arn "${TOPIC_ARN}" \
  --subject "[TEST] DevSecOps Pipeline Alert" \
  --message "Test notification from operational runbook. No action required." \
  --region af-south-1
```

---

## Section 4: Maintenance Schedule

| Task | Frequency | Owner |
|---|---|---|
| Review pipeline failure trends | Weekly | Platform Engineering |
| Update tool versions (Trivy, Semgrep, gitleaks) | Monthly | Platform Engineering |
| Review and renew security waivers | Monthly | Cloud Security |
| AWS CodeBuild image update | Quarterly | Platform Engineering |
| Rotate GitHub connection if near expiry | As needed | Platform Engineering |
| Security posture review (all gates) | Quarterly | Security Architect |
| Full DR test | Bi-annually | Platform Engineering |

---

*Review: Quarterly | Owner: Platform Engineering*
