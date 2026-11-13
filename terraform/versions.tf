terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # S3 Vectors + Bedrock Knowledge Base integration needs provider 6.27.0 or newer.
      version = ">= 6.27"
    }
  }

  # Partial config: bucket/key/region are passed by the pipeline with -backend-config.
  backend "s3" {}
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Repo        = "rag-platform-infra"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  name       = "${var.project}-${var.environment}"
  oidc_host  = "token.actions.githubusercontent.com"
}
