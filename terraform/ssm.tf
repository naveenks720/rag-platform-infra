# The app repo discovers the platform through these parameters, so the two repos
# never share Terraform state or hard-coded IDs.
locals {
  ssm_prefix = "/${var.project}/${var.environment}"

  published = {
    "knowledge-base-id"  = aws_bedrockagent_knowledge_base.this.id
    "knowledge-base-arn" = aws_bedrockagent_knowledge_base.this.arn
    "data-source-id"     = aws_bedrockagent_data_source.docs.data_source_id
    "docs-bucket"        = aws_s3_bucket.docs.bucket
  }
}

resource "aws_ssm_parameter" "published" {
  for_each = local.published

  name  = "${local.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value
}
