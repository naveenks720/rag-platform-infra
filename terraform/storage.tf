# ------------------------------------------------------------------ source docs
resource "aws_s3_bucket" "docs" {
  bucket        = "${local.name}-docs-${local.account_id}"
  force_destroy = var.docs_bucket_force_destroy
}

resource "aws_s3_bucket_versioning" "docs" {
  bucket = aws_s3_bucket.docs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "docs" {
  bucket = aws_s3_bucket.docs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "docs" {
  bucket                  = aws_s3_bucket.docs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ------------------------------------------------------------- vector store
resource "aws_s3vectors_vector_bucket" "kb" {
  vector_bucket_name = "${local.name}-vectors-${local.account_id}"
}

resource "aws_s3vectors_index" "kb" {
  vector_bucket_name = aws_s3vectors_vector_bucket.kb.vector_bucket_name
  index_name         = "${local.name}-index"
  data_type          = "float32"
  dimension          = var.embedding_dimensions
  distance_metric    = "cosine"

  # Bedrock stores each chunk's raw text as metadata; it is too large to filter on.
  metadata_configuration {
    non_filterable_metadata_keys = ["AMAZON_BEDROCK_TEXT"]
  }
}
