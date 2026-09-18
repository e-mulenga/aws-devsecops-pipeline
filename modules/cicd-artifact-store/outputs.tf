output "bucket_name" {
  value = aws_s3_bucket.pipeline_artifacts.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.pipeline_artifacts.arn
}
