variable "region" {
  type    = string
  default = "us-east-1"
}

variable "github_org" {
  description = "GitHub user or organization that owns both repos"
  type        = string
}

variable "infra_repo" {
  description = "Name of this repository"
  type        = string
  default     = "rag-platform-infra"
}

variable "github_owner_id" {
  description = "Numeric ID of the GitHub user/org (it appears in the OIDC subject, e.g. naveenks720@25269118)"
  type        = string
  default     = ""
}

variable "infra_repo_id" {
  description = "Numeric ID of this repository (it appears in the OIDC subject, e.g. rag-platform-infra@1457102834)"
  type        = string
  default     = ""
}

variable "state_bucket_prefix" {
  description = "Prefix for the state bucket name (bucket becomes <prefix>-tfstate-<account id>)"
  type        = string
  default     = "rag-platform"
}
