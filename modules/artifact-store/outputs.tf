output "bucket_name" { 
    value = aws_s3_bucket.artifacts.bucket 
}

output "bucket_arn" { 
    value = aws_s3_bucket.artifacts.arn 
}

output "bucket_id" { 
    value = aws_s3_bucket.artifacts.id 
}

output "pipeline_log_group" { 
    value = aws_cloudwatch_log_group.pipeline.name 
}
