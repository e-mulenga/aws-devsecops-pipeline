# Regional availability

Checked on 2026-11-25 against the AWS General Reference service endpoint pages. Cape Town (af-south-1) is the primary Region. Where a service is missing there, it runs from Ireland (eu-west-1) through the `aws.ireland` provider alias. No other Region is used.

| Service | af-south-1 | eu-west-1 | Where it runs here | Source |
|---|---|---|---|---|
| AWS CodePipeline | Yes | Yes | eu-west-1 (follows the connection) | https://docs.aws.amazon.com/general/latest/gr/codepipeline.html |
| AWS CodeBuild | Yes | Yes | eu-west-1 (same Region as the pipeline) | https://docs.aws.amazon.com/general/latest/gr/codebuild.html |
| AWS CodeConnections | **No** | Yes | eu-west-1 | https://docs.aws.amazon.com/general/latest/gr/codeconnections.html |
| AWS CodeArtifact | **No** | Yes | eu-west-1 | https://docs.aws.amazon.com/general/latest/gr/codeartifact.html |
| Amazon ECR | Yes | Yes | af-south-1 (Landing Zone repository) | consumed from the Landing Zone |
| AWS Secrets Manager | Yes | Yes | read at build time | https://docs.aws.amazon.com/general/latest/gr/asm.html |

## Consequences

- A GitHub source connection must exist in the same Region as the pipeline that uses it. CodeConnections is not in af-south-1, so the whole pipeline (CodePipeline, CodeBuild, artifact bucket, alerting topics) runs in eu-west-1.
- CodeArtifact is also not in af-south-1, so the package proxy runs in eu-west-1 next to CodeBuild.
- Container images are pushed to the Landing Zone ECR repository in af-south-1. CodeBuild logs in to that registry with `--region $ECR_REGION`; the build moves image layers across Regions.
- Landing Zone KMS keys exist in af-south-1 only. Ireland resources therefore use AWS-managed encryption (docs/finops-and-kms.md).
- The Landing Zone platform SNS topic is in af-south-1. EventBridge rules and CloudWatch alarms can notify only a topic in their own Region, so this stack owns an Ireland alerts topic.
- The Landing Zone log buckets are in us-east-1 and cannot receive S3 access logs from an eu-west-1 bucket, so the artifact bucket has its own access-log bucket.

Re-check this table before any change that adds a service. If CodeConnections or CodeArtifact become available in af-south-1, move the pipeline and drop the alias (docs/roadmap.md).
