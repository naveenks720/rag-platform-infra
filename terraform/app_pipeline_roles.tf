# IAM roles that the *app repo's* GitHub Actions pipelines assume (via OIDC).
# They live in this repo so the platform team controls what the app team can touch.

data "aws_iam_openid_connect_provider" "github" {
  url = "https://${local.oidc_host}"
}

# GitHub puts immutable numeric IDs in the OIDC subject, for example
#   repo:naveenks720@25269118/rag-app@<repo id>:pull_request
# With both IDs set the trust policies match that form; without them they fall back to the
# older name-only form (repo:naveenks720/rag-app:pull_request).
locals {
  app_sub_prefix = (
    var.github_owner_id != "" && var.app_repo_id != ""
    ? "repo:${var.github_org}@${var.github_owner_id}/${var.app_repo}@${var.app_repo_id}"
    : "repo:${var.github_org}/${var.app_repo}"
  )
}

data "aws_iam_policy_document" "app_trust_plan" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["${local.app_sub_prefix}:pull_request"]
    }
  }
}

data "aws_iam_policy_document" "app_trust_deploy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["${local.app_sub_prefix}:environment:production"]
    }
  }
}

# ---- plan role: read-only, can read its own state
resource "aws_iam_role" "app_plan" {
  name               = "${var.project}-app-plan"
  assume_role_policy = data.aws_iam_policy_document.app_trust_plan.json
}

resource "aws_iam_role_policy_attachment" "app_plan_readonly" {
  role       = aws_iam_role.app_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

data "aws_iam_policy_document" "app_state_read" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket_name}"]
  }
  statement {
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.state_bucket_name}/rag-app/*"]
  }
}

resource "aws_iam_role_policy" "app_plan_state" {
  name   = "tfstate-read"
  role   = aws_iam_role.app_plan.id
  policy = data.aws_iam_policy_document.app_state_read.json
}

# ---- deploy role: only what the app stack needs
resource "aws_iam_role" "app_deploy" {
  name               = "${var.project}-app-deploy"
  assume_role_policy = data.aws_iam_policy_document.app_trust_deploy.json
}

data "aws_iam_policy_document" "app_deploy" {
  statement {
    sid       = "TerraformState"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.state_bucket_name}"]
  }
  statement {
    sid       = "TerraformStateObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.state_bucket_name}/rag-app/*"]
  }

  statement {
    sid       = "LambdaForApp"
    actions   = ["lambda:*"]
    resources = ["arn:aws:lambda:${var.region}:${local.account_id}:function:rag-app-*"]
  }

  statement {
    sid = "IamRolesForApp"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:GetRole",
      "iam:PassRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PutRolePolicy",
      "iam:GetRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/rag-app-*"]
  }

  statement {
    sid       = "LogsForApp"
    actions   = ["logs:*"]
    resources = ["arn:aws:logs:${var.region}:${local.account_id}:log-group:/aws/lambda/rag-app-*", "arn:aws:logs:${var.region}:${local.account_id}:log-group:/aws/lambda/rag-app-*:*"]
  }
  statement {
    sid       = "LogsDescribe"
    actions   = ["logs:DescribeLogGroups", "logs:ListTagsForResource"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadPlatformParameters"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = ["arn:aws:ssm:${var.region}:${local.account_id}:parameter${local.ssm_prefix}/*"]
  }

  statement {
    sid       = "SyncDocs"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.docs.arn]
  }
  statement {
    sid       = "SyncDocsObjects"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.docs.arn}/*"]
  }

  statement {
    sid       = "StartIngestion"
    actions   = ["bedrock:StartIngestionJob", "bedrock:GetIngestionJob", "bedrock:ListIngestionJobs"]
    resources = [aws_bedrockagent_knowledge_base.this.arn]
  }
}

resource "aws_iam_role_policy" "app_deploy" {
  name   = "app-deploy"
  role   = aws_iam_role.app_deploy.id
  policy = data.aws_iam_policy_document.app_deploy.json
}
