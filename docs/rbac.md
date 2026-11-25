# Roles and permissions

| Role | Trusted by | Can | Cannot |
|---|---|---|---|
| CodePipeline role | `codepipeline.amazonaws.com` | Read and write the artifact bucket, start CodeBuild projects, use the GitHub connection, publish approval notifications | Deploy, read secrets, touch ECR |
| CodeBuild role | `codebuild.amazonaws.com` | Write build logs, read/write the artifact bucket, log in to and push to the Landing Zone ECR repository, read secrets under `<org>/*`, use CodeArtifact, assume the three deploy roles | Create IAM, change the Landing Zone, push to other repositories |
| Slack notifier role | `lambda.amazonaws.com` | Read one webhook secret, write its logs and DLQ | Anything else |
| `<org>-pipeline-deploy-role` (in each target account) | The pipeline account's CodeBuild role | Deploy workloads (policies/iam/pipeline-deployment-role.json) | Administer the account |

Removed in this refactor: the `CloudWatchLogsFullAccess` managed policy (replaced by the scoped log statement), `securityhub:BatchImportFindings` and the Inspector statement (nothing in the buildspecs used them), and the KMS statements (there is no customer key in Ireland).
