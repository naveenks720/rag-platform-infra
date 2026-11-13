output "knowledge_base_id" {
  value = aws_bedrockagent_knowledge_base.this.id
}

output "data_source_id" {
  value = aws_bedrockagent_data_source.docs.data_source_id
}

output "docs_bucket" {
  value = aws_s3_bucket.docs.bucket
}

output "ssm_prefix" {
  value = local.ssm_prefix
}

output "app_plan_role_arn" {
  description = "Set as the AWS_PLAN_ROLE_ARN GitHub variable in the app repo"
  value       = aws_iam_role.app_plan.arn
}

output "app_deploy_role_arn" {
  description = "Set as the AWS_DEPLOY_ROLE_ARN GitHub variable in the app repo"
  value       = aws_iam_role.app_deploy.arn
}
