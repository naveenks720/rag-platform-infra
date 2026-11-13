output "tf_state_bucket" {
  description = "Set as the TF_STATE_BUCKET GitHub variable in both repos"
  value       = aws_s3_bucket.tfstate.bucket
}

output "aws_plan_role_arn" {
  description = "Set as the AWS_PLAN_ROLE_ARN GitHub variable in this repo"
  value       = aws_iam_role.infra_plan.arn
}

output "aws_apply_role_arn" {
  description = "Set as the AWS_APPLY_ROLE_ARN GitHub variable in this repo"
  value       = aws_iam_role.infra_apply.arn
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}
