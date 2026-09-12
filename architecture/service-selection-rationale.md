# Service Selection Rationale
## AWS DevSecOps Pipeline

> Maps every AWS and third-party tool to its business, security, operational, and compliance justification.

---

## AWS CodePipeline

### Why Selected
CodePipeline is the native AWS CI/CD orchestrator. It integrates without agents into CodeBuild, CodeDeploy, Lambda, CloudFormation, and third-party tools. Its stage/action model maps exactly to the DevSecOps pipeline pattern: Source → Security Gates → Build → Security Scan → Test → Staged Deploy.

### Problem It Solves
- **Business:** Eliminates manual deployment steps that introduce human error and slow release velocity.
- **Technical:** Provides a visual stage model for every deployment with built-in approval gates and audit history.

### Alternatives Considered
| Alternative | Why Not Selected |
|---|---|
| GitHub Actions (full pipeline) | No native CodeArtifact/Inspector integration; harder cross-account IAM |
| Jenkins | Self-managed; security patching burden; no native AWS integration |
| GitLab CI | Excellent but adds SaaS cost and complexity when AWS-native works |

### Well-Architected Alignment
- **Operational Excellence:** Automated, repeatable, auditable deployments
- **Security:** Approval gates prevent unauthorised production changes
- **Reliability:** Automatic rollback on stage failure

### Enterprise Use Case
A retail enterprise uses CodePipeline with multi-account deployment to enforce that no code reaches production without passing SAST, DAST, and container scanning — with an immutable audit trail in CloudTrail.

---

## AWS CodeBuild

### Why Selected
CodeBuild is a managed, serverless build service. It scales to zero between builds (no idle cost), supports Docker builds with privileged mode, VPC access for private dependency resolution, and integrates natively with ECR, CodeArtifact, and Secrets Manager.

### Problem It Solves
- **Cost:** Pay only per build-minute — no EC2 instances running 23 hours idle per day.
- **Security:** Each build runs in an isolated, ephemeral container; no state persists between builds.
- **Scalability:** Concurrent builds scale automatically; no queue management.

### Alternatives Considered
| Alternative | Why Not Selected |
|---|---|
| GitHub Actions runners | Requires self-hosted for VPC access; adds runner management overhead |
| Jenkins agents on EC2 | 24/7 EC2 cost; patching burden; no ephemeral isolation |
| AWS Fargate tasks | More complex orchestration; CodeBuild has built-in CodePipeline integration |

### Well-Architected Alignment
- **Cost Optimization:** Zero idle compute cost
- **Security:** Ephemeral build environment; no persistent secrets
- **Sustainability:** Serverless — no over-provisioned instances

---

## Amazon ECR (Elastic Container Registry)

### Why Selected
ECR is the native AWS private container registry with built-in Amazon Inspector v2 scanning (enhanced scanning), KMS encryption, tag immutability in prod, lifecycle policies, and cross-account pull access via repository policies. No additional SaaS cost or authentication complexity.

### Problem It Solves
- **Security:** Inspector v2 ENHANCED scanning performs continuous vulnerability assessment against the NIST NVD — not just on push but as new CVEs are discovered.
- **Compliance:** Tag immutability in prod ensures the image that passed security gates cannot be overwritten.
- **Cost:** Pull-through cache eliminates direct internet egress to Docker Hub from build environments.

### Alternatives Considered
| Alternative | Why Not Selected |
|---|---|
| Docker Hub | No native AWS IAM integration; rate limits; no Inspector integration |
| JFrog Artifactory | Excellent but adds significant SaaS cost |
| GitHub Container Registry | No Inspector integration; requires separate auth from AWS |

### Well-Architected Alignment
- **Security:** KMS encryption, tag immutability, continuous scanning via Inspector
- **Cost Optimization:** Pull-through cache reduces external data transfer costs
- **Reliability:** Regional replication available; no dependency on external SaaS

---

## Amazon Inspector v2 (ECR Enhanced Scanning)

### Why Selected
Inspector v2 integrates directly with ECR and performs continuous scanning — meaning a container image that passes a scan today will be re-evaluated if a new CVE is published tomorrow, without re-running the pipeline. Inspector v2 findings appear in Security Hub, providing a unified security posture view.

### Problem It Solves
Traditional "scan on push" misses zero-days published after deployment. Inspector v2's continuous scanning ensures running containers are monitored for new vulnerabilities throughout their operational lifetime.

### Well-Architected Alignment
- **Security:** Continuous vulnerability monitoring beyond the pipeline
- **Operational Excellence:** Findings surface in Security Hub — consumed by `aws-cloud-security-operations-center`

---

## AWS CodeArtifact

### Why Selected
CodeArtifact provides a private, managed package registry that proxies npm, pip, and maven from public upstream repositories. Build agents pull packages from CodeArtifact — never directly from the internet. This prevents dependency confusion attacks and typosquatting, and allows the security team to audit and block packages centrally.

### Problem It Solves
- **Security:** Eliminates direct internet package downloads from build environments.
- **Reliability:** Packages are cached; builds succeed even when upstream registries have outages.
- **Governance:** Centralised package approval prevents use of unlicensed or vulnerable dependencies.

### Alternatives Considered
| Alternative | Why Not Selected |
|---|---|
| Direct npm/pip/maven from internet | Dependency confusion and supply chain attack risk |
| Nexus Repository | Excellent but requires self-managed EC2; patching overhead |
| GitHub Packages | No CodeBuild-native IAM integration; additional SaaS dependency |

### Well-Architected Alignment
- **Security:** Supply chain attack prevention
- **Reliability:** Cached packages eliminate upstream SaaS dependency
- **Cost Optimization:** Reduced NAT Gateway traffic for package downloads

---

## Gitleaks (Secret Detection)

### Why Selected
Gitleaks is the industry-standard open-source secrets scanner. It runs in under 60 seconds on most repositories, scans full git history (not just the diff), supports 150+ built-in patterns (AWS keys, private keys, connection strings, tokens), and outputs SARIF for GitHub Security tab integration.

### Problem It Solves
Developers accidentally commit secrets every day. Without automated detection in the pipeline, those secrets reach main and potentially production. Gitleaks catches secrets before they are ever deployed and forces immediate credential rotation.

### Well-Architected Alignment
- **Security:** Prevents credential compromise before code reaches the branch
- **Operational Excellence:** Automated detection; no manual secret audits required

---

## Semgrep (SAST)

### Why Selected
Semgrep is a fast, open-source SAST tool with pre-built rulesets for OWASP Top 10, CWE Top 25, and AWS security patterns. It runs in under 2 minutes on most codebases, supports 30+ languages, and outputs SARIF. Unlike CodeGuru (AWS-native), Semgrep covers all languages without per-line pricing.

### Alternatives Considered
| Alternative | Why Not Selected |
|---|---|
| Amazon CodeGuru Reviewer | Only Java and Python; per-line pricing at scale |
| SonarQube | Excellent but requires self-managed or SaaS with additional cost |
| Snyk | Great supply-chain focus but adds per-developer SaaS cost |

### Well-Architected Alignment
- **Security:** Catches SQL injection, XSS, insecure deserialization, hardcoded credentials in code
- **Cost Optimization:** Open-source; no per-developer licensing cost

---

## Trivy (Container & IaC Scanning)

### Why Selected
Trivy is a comprehensive, fast vulnerability scanner supporting container images, filesystems, git repositories, and IaC configurations (Terraform, Dockerfile, Kubernetes). It integrates with SARIF output and covers OS packages, language libraries, and IaC misconfigurations in a single tool.

### Well-Architected Alignment
- **Security:** Vulnerability detection across OS, language dependencies, and IaC
- **Cost Optimization:** Open-source; replaces multiple commercial point tools

---

## Syft (SBOM Generation)

### Why Selected
Syft (by Anchore) generates Software Bill of Materials in CycloneDX and SPDX formats. SBOMs are required by US Executive Order 14028 (Improving the Nation's Cybersecurity) and EU Cyber Resilience Act. Generating an SBOM per pipeline run creates an auditable artefact mapping every deployed image to its exact dependency tree.

### Problem It Solves
When a new CVE is published, organisations need to know immediately which deployed applications are affected. Without an SBOM, this requires re-scanning every running container. With an SBOM archive, a simple grep against CVE package names identifies affected deployments in seconds.

### Well-Architected Alignment
- **Security:** Supply chain transparency and compliance
- **Operational Excellence:** Rapid CVE impact assessment from SBOM archive

---

## OWASP ZAP (DAST)

### Why Selected
ZAP (Zed Attack Proxy) is the world's most widely used open-source DAST tool. It performs active scanning against running applications — finding runtime vulnerabilities like authentication bypass, parameter tampering, and injection flaws that SAST cannot detect from code alone. Runs as a Docker container; no infrastructure management required.

### Well-Architected Alignment
- **Security:** Detects runtime vulnerabilities that static analysis cannot
- **Cost Optimization:** Open-source; no licensing cost

---

## Amazon SNS (Notifications)

### Why Selected
SNS is the native AWS notification service for fan-out messaging. It delivers approval requests, failure alerts, and success notifications to email, Slack (via Lambda), and PagerDuty (via email endpoint). A single SNS topic with multiple subscriptions enables notification routing without changing CodePipeline configuration.

### Well-Architected Alignment
- **Operational Excellence:** Real-time awareness of pipeline state for all stakeholders
- **Reliability:** Managed service; no notification infrastructure to maintain

---

*Owner: Cloud Security & Platform Engineering | Review: Quarterly*
