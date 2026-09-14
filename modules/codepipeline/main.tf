# ============================================================
# Module: codepipeline — DevSecOps Pipeline Orchestrator
# ============================================================
# WAF Pillars: Operational Excellence, Security, Reliability
#
# Pipeline stage sequence:
#  Source → SecretScan → SAST → Build → ContainerScan →
#  IaCScan → SBOM → IntegrationTest → DAST →
#  DeployDev → [Approval] → DeployTest →
#  [CAB Approval] → DeployProd
# ============================================================

resource "aws_codepipeline" "main" {
  name     = "${var.organization_name}-${var.environment}-devsecops-pipeline"
  role_arn = var.pipeline_role_arn

  artifact_store {
    location = var.artifact_bucket_name
    type     = "S3"
    encryption_key {
      id   = var.kms_key_arn
      type = "KMS"
    }
  }

  # ---- Stage 1: Source ----------------------------------------
  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = var.source_provider == "CodeCommit" ? "CodeCommit" : "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = var.source_provider == "CodeCommit" ? {
        RepositoryName       = var.repository_name
        BranchName           = var.branch_name
        PollForSourceChanges = "false"
      } : {
        ConnectionArn        = var.github_connection_arn
        FullRepositoryId     = var.repository_name
        BranchName           = var.branch_name
        OutputArtifactFormat = "CODE_ZIP"
        DetectChanges        = "true"
      }
    }
  }

  # ---- Stage 2: Pre-Build Security — Secret Scan ---------------
  stage {
    name = "PreBuildSecurity"
    action {
      name             = "SecretScan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["SecretScanArtifact"]
      run_order        = 1

      configuration = {
        ProjectName = var.secret_scan_project_name
        EnvironmentVariables = jsonencode([
          { name = "STAGE", value = "secret-scan", type = "PLAINTEXT" }
        ])
      }
    }

    dynamic "action" {
      for_each = var.sast_enabled ? [1] : []
      content {
        name             = "SAST"
        category         = "Build"
        owner            = "AWS"
        provider         = "CodeBuild"
        version          = "1"
        input_artifacts  = ["SourceArtifact"]
        output_artifacts = ["SASTArtifact"]
        run_order        = 1

        configuration = {
          ProjectName = var.sast_project_name
        }
      }
    }
  }

  # ---- Stage 3: Build + Unit Tests ----------------------------
  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact", "ImageDefinitions"]
      run_order        = 1

      configuration = {
        ProjectName = var.build_project_name
      }
    }
  }

  # ---- Stage 4: Post-Build Security Gates ---------------------
  stage {
    name = "SecurityGates"

    action {
      name             = "ContainerScan"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["BuildArtifact"]
      output_artifacts = ["ContainerScanArtifact"]
      run_order        = 1

      configuration = {
        ProjectName = var.container_scan_project_name
      }
    }

    dynamic "action" {
      for_each = var.iac_scan_enabled ? [1] : []
      content {
        name             = "IaCScan"
        category         = "Build"
        owner            = "AWS"
        provider         = "CodeBuild"
        version          = "1"
        input_artifacts  = ["SourceArtifact"]
        output_artifacts = ["IaCScanArtifact"]
        run_order        = 1

        configuration = {
          ProjectName = var.iac_scan_project_name
        }
      }
    }

    dynamic "action" {
      for_each = var.sbom_enabled ? [1] : []
      content {
        name             = "SBOM"
        category         = "Build"
        owner            = "AWS"
        provider         = "CodeBuild"
        version          = "1"
        input_artifacts  = ["BuildArtifact"]
        output_artifacts = ["SBOMArtifact"]
        run_order        = 1

        configuration = {
          ProjectName = var.sbom_project_name
        }
      }
    }
  }

  # ---- Stage 5: Deploy to DEV ---------------------------------
  stage {
    name = "DeployDev"
    action {
      name             = "DeployToDev"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["BuildArtifact", "ImageDefinitions"]
      output_artifacts = ["DeployDevArtifact"]
      run_order        = 1

      configuration = {
        ProjectName = var.deploy_dev_project_name
      }
    }
  }

  # ---- Stage 6: Integration Tests + DAST ---------------------
  stage {
    name = "IntegrationAndDASTTests"

    action {
      name             = "IntegrationTest"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["DeployDevArtifact"]
      output_artifacts = ["IntegrationTestArtifact"]
      run_order        = 1

      configuration = {
        ProjectName = var.integration_test_project_name
      }
    }

    dynamic "action" {
      for_each = var.dast_enabled ? [1] : []
      content {
        name             = "DAST"
        category         = "Build"
        owner            = "AWS"
        provider         = "CodeBuild"
        version          = "1"
        input_artifacts  = ["DeployDevArtifact"]
        output_artifacts = ["DASTArtifact"]
        run_order        = 2

        configuration = {
          ProjectName = var.dast_project_name
        }
      }
    }
  }

  # ---- Stage 7: Approval for TEST -----------------------------
  dynamic "stage" {
    for_each = var.require_test_approval ? [1] : []
    content {
      name = "ApproveTest"
      action {
        name      = "ApproveDeployToTest"
        category  = "Approval"
        owner     = "AWS"
        provider  = "Manual"
        version   = "1"
        run_order = 1

        configuration = {
          NotificationArn    = var.approval_sns_topic_arn
          CustomData         = "Security gates passed. Approve to promote to TEST environment."
          ExternalEntityLink = "https://console.aws.amazon.com/codesuite/codepipeline/pipelines/${var.organization_name}-${var.environment}-devsecops-pipeline/view"
        }
      }
    }
  }

  # ---- Stage 8: Deploy to TEST --------------------------------
  stage {
    name = "DeployTest"
    action {
      name             = "DeployToTest"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["BuildArtifact", "ImageDefinitions"]
      output_artifacts = ["DeployTestArtifact"]
      run_order        = 1

      configuration = {
        ProjectName = var.deploy_test_project_name
      }
    }
  }

  # ---- Stage 9: CAB Approval for PROD -------------------------
  dynamic "stage" {
    for_each = var.require_prod_approval ? [1] : []
    content {
      name = "ApproveProd"
      action {
        name      = "CABApproveDeployToProd"
        category  = "Approval"
        owner     = "AWS"
        provider  = "Manual"
        version   = "1"
        run_order = 1

        configuration = {
          NotificationArn = var.approval_sns_topic_arn
          CustomData      = "CAB APPROVAL REQUIRED: Test environment validated. This will deploy to PRODUCTION. Ensure change ticket is approved."
          ExternalEntityLink = "https://console.aws.amazon.com/codesuite/codepipeline/pipelines/${var.organization_name}-${var.environment}-devsecops-pipeline/view"
        }
      }
    }
  }

  # ---- Stage 10: Deploy to PROD -------------------------------
  stage {
    name = "DeployProd"
    action {
      name             = "DeployToProduction"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["BuildArtifact", "ImageDefinitions"]
      output_artifacts = ["DeployProdArtifact"]
      run_order        = 1

      configuration = {
        ProjectName = var.deploy_prod_project_name
      }
    }
  }

  tags = { Name = "${var.organization_name}-${var.environment}-devsecops-pipeline" }
}

# ---- CodePipeline Notification Rule -------------------------
 resource "aws_codestarnotifications_notification_rule" "pipeline" {
   name        = "${var.organization_name}-${var.environment}-pipeline-notifications"
   resource    = aws_codepipeline.main.arn
   detail_type = "FULL"

   event_type_ids = [
     "codepipeline-pipeline-pipeline-execution-succeeded",
     "codepipeline-pipeline-pipeline-execution-failed",
     "codepipeline-pipeline-pipeline-execution-canceled",
     "codepipeline-pipeline-manual-approval-needed",
     "codepipeline-pipeline-manual-approval-succeeded",
     "codepipeline-pipeline-manual-approval-failed"
   ]

   target {
     type    = "SNS"
     address = var.approval_sns_topic_arn
   }

   tags = { Name = "${var.organization_name}-${var.environment}-pipeline-notifications" }
 }

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

terraform {
  required_version = ">= 1.5.0"
}