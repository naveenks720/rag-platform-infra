locals {
  embedding_model_arn = "arn:aws:bedrock:${var.region}::foundation-model/${var.embedding_model_id}"
}

# -------------------------------------------- role the Knowledge Base assumes
data "aws_iam_policy_document" "kb_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:aws:bedrock:${var.region}:${local.account_id}:knowledge-base/*"]
    }
  }
}

data "aws_iam_policy_document" "kb_permissions" {
  statement {
    sid       = "EmbedWithTitan"
    actions   = ["bedrock:InvokeModel"]
    resources = [local.embedding_model_arn]
  }
  statement {
    sid       = "ListDocs"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.docs.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceAccount"
      values   = [local.account_id]
    }
  }
  statement {
    sid       = "ReadDocs"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.docs.arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceAccount"
      values   = [local.account_id]
    }
  }
  statement {
    sid = "ReadWriteVectors"
    actions = [
      "s3vectors:GetIndex",
      "s3vectors:PutVectors",
      "s3vectors:GetVectors",
      "s3vectors:DeleteVectors",
      "s3vectors:QueryVectors",
      "s3vectors:ListVectors",
    ]
    resources = [
      aws_s3vectors_vector_bucket.kb.vector_bucket_arn,
      "${aws_s3vectors_vector_bucket.kb.vector_bucket_arn}/*",
    ]
  }
}

resource "aws_iam_role" "kb" {
  name               = "${local.name}-kb-role"
  assume_role_policy = data.aws_iam_policy_document.kb_trust.json
}

resource "aws_iam_role_policy" "kb" {
  name   = "kb-permissions"
  role   = aws_iam_role.kb.id
  policy = data.aws_iam_policy_document.kb_permissions.json
}

# ---------------------------------------------------------- knowledge base
resource "aws_bedrockagent_knowledge_base" "this" {
  name     = "${local.name}-kb"
  role_arn = aws_iam_role.kb.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = local.embedding_model_arn
      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions          = var.embedding_dimensions
          embedding_data_type = "FLOAT32"
        }
      }
    }
  }

  storage_configuration {
    type = "S3_VECTORS"
    s3_vectors_configuration {
      index_arn = aws_s3vectors_index.kb.index_arn
    }
  }

  depends_on = [aws_iam_role_policy.kb]
}

resource "aws_bedrockagent_data_source" "docs" {
  name                 = "${local.name}-docs"
  knowledge_base_id    = aws_bedrockagent_knowledge_base.this.id
  data_deletion_policy = "RETAIN"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.docs.arn
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = var.chunk_max_tokens
        overlap_percentage = var.chunk_overlap_percentage
      }
    }
  }
}
