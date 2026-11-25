# Landing Zone integration

This stack reads the Landing Zone through `terraform_remote_state` (`landing_zone.tf`) and refuses to plan unless `contract_schema_version` is `"2"`.

| Landing Zone output | Used for |
|---|---|
| `contract_schema_version` | Precondition on `terraform_data.landing_zone_contract` |
| `ecr_repository_urls` | The registry the pipeline pushes to (`ecr_repository_key`, default `shared-devsecops`) |
| `eu_west_1.region` | Precondition: `ireland_region` must match |
| `key_strategy` | Recorded in `local.key_strategy` for documentation and future CMK decisions |

## Never created here

VPCs, subnets, NAT, endpoints, KMS keys, ECR repositories, the registry scanning configuration, Security Hub, GuardDuty, Inspector, log buckets, the Route 53 zone, ACM certificates, the platform SNS topic, state buckets and the GitHub OIDC provider. `tests/test_posture.py` fails if a matching `resource` block appears.

## Created here

CodePipeline, CodeBuild projects, the artifact bucket and its access-log bucket, CodeArtifact, the pipeline IAM roles, the Ireland alerts and approval topics, EventBridge rules, the optional Slack notifier, one alarm and one dashboard.
