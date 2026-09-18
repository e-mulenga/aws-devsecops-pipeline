output "secret_scan_project_name" { 
    value = aws_codebuild_project.main["secret-scan"].name 
}

output "sast_project_name" { 
    value = aws_codebuild_project.main["sast"].name 
}

output "build_project_name" { 
    value = aws_codebuild_project.main["build"].name 
}

output "container_scan_project_name" { 
    value = aws_codebuild_project.main["container-scan"].name 
}

output "iac_scan_project_name" { 
    value = aws_codebuild_project.main["iac-scan"].name 
}

output "sbom_project_name" { 
    value = aws_codebuild_project.main["sbom"].name 
}

output "integration_test_project_name" { 
    value = aws_codebuild_project.main["integration-test"].name 
}

output "dast_project_name" { 
    value = aws_codebuild_project.main["dast"].name 
}

output "deploy_dev_project_name" { 
    value = aws_codebuild_project.main["deploy-dev"].name 
}

output "deploy_test_project_name" { 
    value = aws_codebuild_project.main["deploy-test"].name 
}

output "deploy_prod_project_name" { 
    value = aws_codebuild_project.main["deploy-prod"].name 
}

output "all_project_names" { 
    value = { for k, v in aws_codebuild_project.main : k => v.name } 
}
