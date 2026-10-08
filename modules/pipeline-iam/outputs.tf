output "codepipeline_role_arn" {
  value = aws_iam_role.codepipeline.arn
}

output "codepipeline_role_name" {
  value = aws_iam_role.codepipeline.name
}

output "codebuild_role_arn" {
  value = aws_iam_role.codebuild.arn
}

output "codebuild_role_name" {
  value = aws_iam_role.codebuild.name
}
