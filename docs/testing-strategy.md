# Testing strategy

| Layer | What | Where |
|---|---|---|
| Static | `terraform fmt -check`, `terraform validate` (no backend, no credentials) | `.github/workflows/ci.yml` |
| Policy as code | tfsec, checkov, trivy (filesystem), gitleaks, bandit | `.github/workflows/security.yml` |
| Unit | Posture tests: no Landing Zone resources recreated, no account IDs, provider.tf only, Ireland alias on every pipeline module, buildspec Region handling | `tests/test_posture.py` |
| Scripts | `bash -n` on every shell script | CI |
| Post-apply | `validation/validate-pipeline.sh` checks stages, projects, bucket versioning and encryption, topics, Landing Zone ECR repository | run per environment |
| Pipeline behaviour | Push a commit with a planted test secret (must block), a known-vulnerable dependency (must block at container scan), a failing unit test (must stop before deploy) | per release |
| Drills | Rotate the GitHub connection; delete the artifact bucket contents and re-run; revoke the deploy role and confirm the deploy stage fails closed | quarterly |

Run locally: `python3 -I -m unittest discover -s tests`.
