output "domain_name" { 
  value = aws_codeartifact_domain.main.domain 
}

output "domain_arn" { 
  value = aws_codeartifact_domain.main.arn 
}

output "repository_name" { 
  value = aws_codeartifact_repository.internal.repository 
}

output "repository_endpoint"   {
  value     = "https://${aws_codeartifact_domain.main.domain}-${data.aws_caller_identity.current.account_id}.d.codeartifact.${data.aws_caller_identity.current.id}.amazonaws.com"
  sensitive = true
}
