# Architecture decision records

## ADR-1: Run the pipeline in eu-west-1
Status: accepted (2026-11-25). CodeConnections and CodeArtifact are not offered in af-south-1 (docs/regional-availability.md). A GitHub connection must be in the pipeline's Region, so the pipeline, CodeBuild, artifact bucket, CodeArtifact and alert topics use the `aws.ireland` alias. Workloads stay in af-south-1.
Consequence: image pushes cross Regions; releases depend on eu-west-1 availability.

## ADR-2: Consume the Landing Zone ECR repository
Status: accepted. The Landing Zone already exports `ecr_repository_urls` (shared-applications, shared-devsecops, shared-platform). This stack no longer creates repositories, lifecycle rules, repository policies, the registry scanning configuration or the pull-through cache. The registry scanning configuration is account-wide, so managing it here would fight the Landing Zone.
Consequence: existing repositories in state must be removed from state, not destroyed (docs/MIGRATION.md).

## ADR-3: Drop the `kms_key_arn` input
Status: accepted. Landing Zone keys are af-south-1 keys and `key_strategy` is `aws-managed`. Ireland resources use AWS-managed encryption. See docs/finops-and-kms.md.

## ADR-4: Leave SNS topics without a customer key
Status: accepted. EventBridge and CodeStar Notifications cannot publish to a topic encrypted with the AWS-managed `alias/aws/sns` key, because its key policy cannot be edited. A customer key would have to be created in Ireland by this repository. Messages contain pipeline names and states only. checkov rule CKV_AWS_26 is skipped with this reference.

## ADR-5: CodeBuild runs outside the VPC
Status: accepted. The Landing Zone has no NAT gateway and no interface endpoints, so a VPC-hosted build could not reach GitHub, package registries or scanner downloads. The VPC variables remain optional for a future change.

## ADR-6: Own access-log bucket for the artifact bucket
Status: accepted. Landing Zone log buckets are in us-east-1 and S3 server access logs require a target bucket in the same Region.

## ADR-7: Deploy targets default to the Landing Zone account
Status: accepted. `dev_account_id`, `test_account_id` and `prod_account_id` are optional. When empty the pipeline deploys into the account it runs in, which matches the single-account Landing Zone. Separate accounts remain supported.

## ADR-8: Findings stay in build artifacts
Status: accepted. The earlier text claimed a Security Hub import that no buildspec performed. Reports are published as build artifacts. Importing to Security Hub is on the roadmap once Security Hub is enabled in eu-west-1.
