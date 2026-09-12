# Contributing Guide
## AWS DevSecOps Pipeline

**Portfolio Position 3 of 6** — Changes here affect `aws-cloud-security-operations-center` and `aws-secure-eks-platform`.

## Security Gate Standards

Every PR must pass ALL security gates before merge:

| Gate | Tool | Block threshold |
|---|---|---|
| Secret detection | gitleaks | Any secret |
| SAST | Semgrep | HIGH/CRITICAL |
| IaC scan | tfsec | HIGH/CRITICAL |
| IaC scan | checkov | HIGH/CRITICAL |
| Container scan | Trivy | HIGH/CRITICAL |
| DAST | OWASP ZAP | HIGH/CRITICAL risk |

## Adding a New Pipeline Stage

1. Add a `buildspec-<stage>.yml` to `buildspecs/`
2. Add a new CodeBuild project in `modules/codebuild/main.tf` `local.projects` map
3. Add a new output to `modules/codebuild/outputs.tf`
4. Wire the stage into `modules/codepipeline/main.tf`
5. Add the output reference to `main.tf` and `outputs.tf`
6. Update README — Architecture Overview and Terraform Structure sections
7. PR label: `enhancement` (minor version bump)

## Terraform Standards

- `provider.tf` contains both `terraform {}` block and providers — **no** `versions.tf`
- All account IDs, regions, emails, and secrets are variables — never hardcoded
- Security defaults ON: encryption, KMS, TLS-only
- `for_each` over `count` for all named resources
- All variables have `type`, `description`, and `default` or explicit required

## Commit Convention

```
feat(codepipeline): add SBOM stage to pipeline
fix(codebuild): increase DAST timeout to 30 minutes
security(iam): scope CodeBuild role to named S3 bucket
docs(readme): add interview talking points section
```

## Running Security Scans Locally

```bash
tfsec . --minimum-severity HIGH
checkov -d . --framework terraform
gitleaks detect --source . --verbose
terraform fmt -check -recursive
```
