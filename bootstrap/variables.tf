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

variable "state_bucket_prefix" {
  description = "Prefix for the state bucket name (bucket becomes <prefix>-tfstate-<account id>)"
  type        = string
  default     = "rag-platform"
}
