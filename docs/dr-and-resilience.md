# Disaster recovery and resilience

| Item | RTO | RPO | Method |
|---|---|---|---|
| Pipeline infrastructure | 2 hours | 0 (code in Git) | `scripts/tf.sh <env> apply` from the repository |
| Source code | n/a | 0 | GitHub is the system of record |
| Artifacts and SBOMs | 1 hour (rebuild by re-running the pipeline) | Last successful build | Versioned bucket; artifacts are reproducible |
| CodeArtifact packages | 4 hours | Last internal publish | Upstream packages re-fetched on demand; internal packages re-published from source |
| Container images | Landing Zone ECR | Landing Zone policy | Owned by the Landing Zone |
| GitHub connection | 30 minutes | 0 | Create a new connection and approve it in the console (runbooks/operational-runbook.md) |

## Failure modes

- eu-west-1 unavailable: running workloads in af-south-1 are unaffected. Releases pause. There is no second pipeline; for an urgent fix, deploy from a workstation with the deploy role. This is an accepted trade-off at this scale.
- af-south-1 unavailable: pushes to the Landing Zone ECR fail at the build stage. The pipeline stops before deploy.
- Bad release: redeploy the previous image definition from the artifact bucket (README, Rollback).

Failure drills are listed in docs/testing-strategy.md.
