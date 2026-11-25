# Business case: DevSecOps pipeline

## Problem
Teams ship containers quickly but find secrets, vulnerable dependencies and misconfigurations late, after release, when fixes cost the most and audits ask for evidence that does not exist.

## Solution
One CodePipeline per environment with six security gates before anything reaches production: secret scan, SAST, container scan, IaC scan, SBOM, DAST. Every run leaves reports and an SBOM in an artifact bucket. Production needs a manual approval.

## Value

| Outcome | Measure |
|---|---|
| Fewer defects in production | Findings caught at the gate, not in prod |
| Faster, repeatable releases | Commit-to-dev time; one path for every service |
| Audit evidence | SBOM and scan reports per release, CloudTrail for every action |
| Lower cost of security | Open-source scanners; pay-per-minute builds with no idle compute |
| Platform reuse | Consumes the Landing Zone registry; no duplicate platform resources |

## Cost
Pay-per-use. See docs/finops-and-kms.md for the drivers and guards. There is no NAT gateway, endpoint or always-on compute.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Scanner false positives slow teams | `sast_failure_action` can be set to WARN per environment; suppressions are reviewed in pull requests |
| Pipeline in Ireland while workloads are in Cape Town | Documented, accepted (ADR-1); releases pause during an Ireland outage, workloads do not |
| Gate bypass | Branch protection, approvals, scoped roles, CloudTrail |
