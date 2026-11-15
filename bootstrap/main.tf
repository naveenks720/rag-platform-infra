# One-time bootstrap. Run locally with admin credentials (local state is fine here).
# Creates what the pipelines themselves depend on:
#   - S3 bucket for Terraform remote state (native S3 locking, no DynamoDB)
#   - GitHub Actions OIDC provider
#   - IAM roles the infra repo's pipelines assume (plan = read-only, apply = admin)

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.27"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  oidc_host  = "token.actions.githubusercontent.com"
}

# ---------------------------------------------------------------- state bucket
resource "aws_s3_bucket" "tfstate" {
  bucket = "${var.state_bucket_prefix}-tfstate-${local.account_id}"
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------- GitHub OIDC
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

# GitHub puts immutable numeric IDs in the OIDC subject, for example
#   repo:naveenks720@25269118/rag-platform-infra@1457102834:pull_request
# When both IDs are provided the trust policies match that form (it cannot be reused by a
# renamed or re-created repo). Without IDs they fall back to the older name-only form:
#   repo:naveenks720/rag-platform-infra:pull_request
locals {
  infra_sub_prefix = (
    var.github_owner_id != "" && var.infra_repo_id != ""
    ? "repo:${var.github_org}@${var.github_owner_id}/${var.infra_repo}@${var.infra_repo_id}"
    : "repo:${var.github_org}/${var.infra_repo}"
  )
}

data "aws_iam_policy_document" "trust_plan" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["${local.infra_sub_prefix}:pull_request"]
    }
  }
}

data "aws_iam_policy_document" "trust_apply" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    # Only jobs that run in the "production" GitHub environment (manual approval) can apply.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["${local.infra_sub_prefix}:environment:production"]
    }
  }
}

resource "aws_iam_role" "infra_plan" {
  name               = "rag-platform-infra-plan"
  assume_role_policy = data.aws_iam_policy_document.trust_plan.json
}

resource "aws_iam_role_policy_attachment" "infra_plan_readonly" {
  role       = aws_iam_role.infra_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "state_read" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tfstate.arn]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*"]
  }
}

resource "aws_iam_role_policy" "infra_plan_state" {
  name   = "tfstate-read"
  role   = aws_iam_role.infra_plan.id
  policy = data.aws_iam_policy_document.state_read.json
}

resource "aws_iam_role" "infra_apply" {
  name               = "rag-platform-infra-apply"
  assume_role_policy = data.aws_iam_policy_document.trust_apply.json
}

# Broad on purpose for a demo, but protected by the OIDC subject above.
# For production, replace with a scoped policy (S3, S3 Vectors, Bedrock, IAM, SSM).
resource "aws_iam_role_policy_attachment" "infra_apply_admin" {
  role       = aws_iam_role.infra_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
