# FinOps and encryption

## Encryption statement

Dev/Test use AWS-managed keys. Prod uses a customer-managed key (CMK) where governance requires it, following the Landing Zone `key_strategy`.

Landing Zone `key_strategy` is `aws-managed` in the current outputs and exports no shared keys. In addition, Landing Zone keys are af-south-1 keys and cannot encrypt eu-west-1 resources. All resources here are in eu-west-1, so:

| Resource | Encryption |
|---|---|
| Artifact bucket and access-log bucket | SSE-KMS with the AWS-managed `aws/s3` key, bucket key on |
| CodeBuild logs, pipeline log group | CloudWatch Logs default encryption |
| SNS topics | Unencrypted at rest by design (ADR-4); messages carry pipeline names and status only |
| SQS dead-letter queue | SQS-managed SSE |
| Lambda environment | AWS-managed `aws/lambda` key |
| CodeArtifact domain | Default AWS-managed encryption |
| ECR images | Landing Zone repository settings (not managed here) |

If governance later requires a CMK in prod, add a repo-owned key in eu-west-1 behind a variable. That is on the roadmap and is the only place this repository would create a key.

## Cost drivers

| Service | Billing | Guard |
|---|---|---|
| CodePipeline | Per active pipeline per month | One pipeline per environment |
| CodeBuild | Per build minute and compute size | SMALL compute for light stages, 30-minute default timeout |
| CodeArtifact | Per GB stored and per request | Upstream proxy only, internal repository for private packages |
| S3 artifact bucket | Per GB and request | 30-day expiry, 7-day noncurrent expiry |
| CloudWatch | Logs ingestion, dashboard, alarm | 365-day retention on log groups, one dashboard, one alarm |
| SNS, EventBridge | Per request | Negligible |
| Cross-Region data transfer | Per GB | Image layers pushed from eu-west-1 to af-south-1; keep images small, use layer caching |

No NAT gateway or interface endpoint is created. The Landing Zone has none, so CodeBuild runs outside the VPC (ADR-5).
