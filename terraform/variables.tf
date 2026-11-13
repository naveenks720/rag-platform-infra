variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "rag-platform"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "embedding_model_id" {
  description = "Bedrock embedding model used to turn chunks and questions into vectors"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"
}

variable "embedding_dimensions" {
  description = "Must match the vector index dimension (Titan V2 supports 256, 512, 1024)"
  type        = number
  default     = 1024
}

variable "chunk_max_tokens" {
  type    = number
  default = 300
}

variable "chunk_overlap_percentage" {
  type    = number
  default = 20
}

variable "docs_bucket_force_destroy" {
  description = "Allow terraform destroy to delete a non-empty docs bucket (demo convenience)"
  type        = bool
  default     = true
}

# --- GitHub / pipeline wiring for the app repo's IAM roles ---
variable "github_org" {
  description = "GitHub user or organization that owns both repos"
  type        = string
}

variable "app_repo" {
  description = "Name of the RAG application repository"
  type        = string
  default     = "rag-app"
}

variable "state_bucket_name" {
  description = "Terraform state bucket created by bootstrap/ (shared with the app repo)"
  type        = string
}
