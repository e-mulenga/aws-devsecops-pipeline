# Roadmap

| Item | Why | Trigger |
|---|---|---|
| Repo-owned CMK in eu-west-1 for prod | Governance may require customer-managed keys where Landing Zone keys cannot be used | Governance requirement |
| Move the pipeline to af-south-1 | Removes the cross-Region image push and the alias | CodeConnections and CodeArtifact available in af-south-1 |
| Import scanner findings into Security Hub | One place for findings | Security Hub enabled in eu-west-1 by the Landing Zone |
| VPC-hosted CodeBuild | Private builds | Landing Zone adds NAT or endpoints in a usable Region |
| Signed images (Sigstore cosign) | Supply chain integrity | Registry policy change in the Landing Zone |
| Pipeline-per-service via a module | Reuse across applications | Second application onboarded |
