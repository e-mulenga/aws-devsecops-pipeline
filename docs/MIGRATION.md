# Migration from the previous version

Read this before the first `plan`. Run it per environment, dev first. Always review the plan; the steps below tell you what to expect.

## 1. Backend
`scripts/tf.sh <env> init` now uses a partial backend with the key `aws-devsecops-pipeline/<env>.tfstate`. If your existing state uses another key, copy it first: `terraform init -migrate-state` with the old key, or use `-backend-config="key=<old key>"` for the first init.

## 2. ECR repositories (do not destroy)
The Landing Zone owns ECR now. Remove the old repositories from state so Terraform forgets them without deleting images:

```bash
scripts/tf.sh <env> state list | grep module.ecr
scripts/tf.sh <env> state rm 'module.ecr'
```

Then point `ecr_repository_key` at the Landing Zone repository and re-tag or re-push images you still need. The registry scanning configuration is account-wide and also leaves state with the module; it keeps its current setting until the Landing Zone changes it.

## 3. Region move
CodePipeline, CodeBuild, the artifact bucket, CodeArtifact and the topics now live in eu-west-1. If they were in af-south-1 they will be replaced, not moved. Expect:

- A new GitHub connection in eu-west-1: run `scripts/setup-github-connection.sh`, approve it in the console, set `github_connection_arn`.
- A new artifact bucket name is needed if the old bucket still exists (bucket names are global): set `artifact_bucket_name`, or empty and delete the old bucket first.
- Re-subscribe notification emails (new topics send a confirmation).
- CodeArtifact packages are re-fetched from upstream; publish internal packages again.

If the stack already ran in eu-west-1 these resources stay in place.

## 4. Encryption
Customer-managed key references are removed. Existing objects stay readable with the old key as long as the old key exists; do not schedule the old key for deletion until the plan has applied and a pipeline run has succeeded.

## 5. Check
`ENV=<env> ORG=<organization_name> bash validation/validate-pipeline.sh`
