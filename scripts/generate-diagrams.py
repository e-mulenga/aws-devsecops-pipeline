#!/usr/bin/env python3
"""Generate architecture/diagrams/*.png (pip install diagrams; needs graphviz `dot`).

Colour convention:
  blue   = consumed from the AWS Enterprise Landing Zone (read through remote state, never recreated)
  green  = created by this repository in eu-west-1 (Ireland alias)
  amber  = workload accounts the pipeline deploys into
  grey   = delivery tooling and people
"""
import os

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.devtools import Codeartifact, Codebuild, Codepipeline
from diagrams.aws.compute import Lambda
from diagrams.aws.general import General
from diagrams.aws.integration import SNS, Eventbridge
from diagrams.aws.management import Cloudwatch, Organizations
from diagrams.aws.security import IAM, SecretsManager
from diagrams.aws.compute import ECR
from diagrams.aws.storage import S3
from diagrams.onprem.client import User, Users
from diagrams.onprem.vcs import Github

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "architecture", "diagrams")
os.makedirs(OUT, exist_ok=True)
LZ = {"bgcolor": "#E8F0FE", "pencolor": "#1A73E8", "style": "rounded", "fontsize": "13"}
IRE = {"bgcolor": "#E6F4EA", "pencolor": "#188038", "style": "rounded", "fontsize": "13"}
WL = {"bgcolor": "#FFF4E0", "pencolor": "#FF9900", "style": "rounded", "fontsize": "13"}
TOOL = {"bgcolor": "#F1F3F4", "pencolor": "#5F6368", "style": "rounded", "fontsize": "13"}
G = {"fontsize": "20", "pad": "0.5", "nodesep": "0.6", "ranksep": "0.9"}


def d(name, title, direction="LR"):
    return Diagram(title, filename=os.path.join(OUT, name), show=False, direction=direction, graph_attr=G, outformat="png")


with d("executive-architecture", "DevSecOps pipeline - executive view"):
    dev = User("Developer")
    gh = Github("Source repository")
    with Cluster("Pipeline (eu-west-1, this repository)", graph_attr=IRE):
        pipe = Codepipeline("CodePipeline\n11 stages, 6 security gates")
    with Cluster("Landing Zone (af-south-1)", graph_attr=LZ):
        reg = ECR("Shared ECR\nrepository")
    with Cluster("Workload accounts", graph_attr=WL):
        wl = General("dev -> test -> prod")
    dev >> gh >> pipe
    pipe >> reg
    pipe >> wl

with d("landing-zone-integration", "Landing Zone integration: consumed vs created", direction="TB"):
    with Cluster("Landing Zone (consumed - never recreated)", graph_attr=LZ):
        state = S3("Remote state\n(contract v2)")
        reg = ECR("ecr_repository_urls")
        keys = Organizations("key_strategy,\neu_west_1 settings")
    with Cluster("This repository (eu-west-1)", graph_attr=IRE):
        stack = General("Terraform stack")
        pipe = Codepipeline("Pipeline + CodeBuild")
        art = S3("Artifact bucket")
        pkg = Codeartifact("CodeArtifact")
    state >> stack
    reg >> Edge(style="dotted") >> pipe
    keys - Edge(style="dotted") - stack
    stack >> pipe
    stack >> art
    stack >> pkg

with d("pipeline-stages", "Pipeline stages and gates"):
    src = Github("Source")
    with Cluster("Gate 1: before build", graph_attr=TOOL):
        sec = Codebuild("Secret scan\n(gitleaks)")
        sast = Codebuild("SAST\n(Semgrep)")
    build = Codebuild("Build + unit tests\n+ image push")
    with Cluster("Gate 2: after build", graph_attr=TOOL):
        cs = Codebuild("Container scan\n(Trivy)")
        iac = Codebuild("IaC scan\n(tfsec, checkov)")
        sbom = Codebuild("SBOM (Syft)")
    dev = Codebuild("Deploy dev")
    with Cluster("Gate 3: running app", graph_attr=TOOL):
        it = Codebuild("Integration tests")
        dast = Codebuild("DAST (ZAP)")
    src >> [sec, sast] >> build >> [cs, iac, sbom] >> dev >> [it, dast]

with d("regional-placement", "Where each service runs", direction="TB"):
    with Cluster("af-south-1 (Cape Town)", graph_attr=LZ):
        reg = ECR("Landing Zone ECR")
        wl = General("Workloads\n(deploy targets)")
        topic = SNS("Platform alerts\n(Landing Zone)")
    with Cluster("eu-west-1 (Ireland alias)", graph_attr=IRE):
        conn = General("CodeConnections\n(GitHub)")
        pipe = Codepipeline("CodePipeline")
        cb = Codebuild("CodeBuild")
        ca = Codeartifact("CodeArtifact")
        ireland_topic = SNS("Pipeline alerts\n(own topic)")
    conn >> pipe >> cb
    cb >> ca
    cb >> Edge(label="push image") >> reg
    cb >> Edge(label="deploy") >> wl
    pipe >> ireland_topic

with d("multi-account-deployment", "Multi-account deployment", direction="TB"):
    with Cluster("Pipeline (eu-west-1)", graph_attr=IRE):
        role = IAM("CodeBuild role")
    with Cluster("dev account", graph_attr=WL):
        dr = IAM("pipeline-deploy-role")
    with Cluster("test account", graph_attr=WL):
        tr = IAM("pipeline-deploy-role")
    with Cluster("prod account", graph_attr=WL):
        pr = IAM("pipeline-deploy-role")
    role >> Edge(label="sts:AssumeRole") >> [dr, tr, pr]

with d("iam-trust", "Roles and trust", direction="TB"):
    with Cluster("This repository", graph_attr=IRE):
        pr = IAM("CodePipeline role")
        cb = IAM("CodeBuild role")
        ln = IAM("Slack notifier role")
    with Cluster("Services", graph_attr=TOOL):
        svc1 = General("codepipeline.amazonaws.com")
        svc2 = General("codebuild.amazonaws.com")
        svc3 = General("lambda.amazonaws.com")
    svc1 >> pr
    svc2 >> cb
    svc3 >> ln
    pr >> Edge(label="StartBuild") >> cb

with d("monitoring-and-alerting", "Monitoring and alerting"):
    pipe = Codepipeline("CodePipeline")
    eb = Eventbridge("State change\nrules")
    topic = SNS("Alerts topic\n(eu-west-1)")
    alarm = Cloudwatch("Failure alarm")
    slack = Lambda("Slack notifier\n(optional)")
    sm = SecretsManager("Webhook secret")
    people = Users("Security team")
    pipe >> eb >> topic
    pipe >> alarm >> topic
    topic >> people
    topic >> slack
    sm >> slack

with d("threat-model", "Threat model: trust boundaries", direction="TB"):
    with Cluster("Untrusted", graph_attr=TOOL):
        pr = Github("Pull request\nfrom a fork")
        dep = General("Public registries")
    with Cluster("Pipeline (eu-west-1)", graph_attr=IRE):
        gate = Codebuild("Scan gates")
        pkg = Codeartifact("CodeArtifact proxy")
        build = Codebuild("Build")
    with Cluster("Trusted targets", graph_attr=WL):
        prod = General("Production")
    pr >> gate >> build >> prod
    dep >> pkg >> build
