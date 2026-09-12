# Security Policy
## AWS DevSecOps Pipeline

## Reporting a Vulnerability

**Email:** security@[your-org].com
**Subject:** `[SECURITY] aws-devsecops-pipeline — <description>`

Do NOT open public GitHub issues for security vulnerabilities.

We acknowledge within **48 hours** and remediate within **5 business days**.

## Security Controls in This Repository

| Control | Implementation |
|---|---|
| No hardcoded secrets | All credentials via Secrets Manager or SSM |
| No hardcoded account IDs | All IDs are variables from landing zone outputs |
| OIDC CI/CD auth | GitHub Actions uses OIDC — no long-lived AWS keys |
| Encrypted artifact store | S3 with KMS CMK, TLS-only bucket policy |
| Encrypted state | S3 backend KMS + DynamoDB lock |
| ECR image immutability | Tag immutability enforced in prod |
| Security gates block merge | tfsec + checkov + gitleaks on every PR |
| Least-privilege IAM | Scoped CodeBuild and CodePipeline roles |
| Cross-account roles | Explicit assume-role, not wildcard trust |

## Responsible Disclosure

- Vulnerabilities in this code: email above
- Vulnerabilities in AWS services used: report to AWS Security
