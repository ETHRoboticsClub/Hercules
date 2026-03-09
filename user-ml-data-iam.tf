## ─────────────────────────────────────────────────────────────────────────────
## IAM access to ML data bucket for namespace-scoped end users
##
## End users are the namespace-scoped IAM users defined in var.cluster_access
## (those with a non-empty namespaces list). They should have read/write access
## to the ML data bucket for uploading datasets, checkpoints, and model
## artefacts.
##
## KMS access to the bucket key is already granted via module "s3_ml_data"
## (kms_user_arns). This file adds the corresponding S3 permissions on the
## bucket itself.
## ─────────────────────────────────────────────────────────────────────────────

locals {
  # Namespace-scoped IAM users (exclude cluster-wide admins and roles).
  ml_ns_iam_users = {
    for k, v in var.cluster_access : k => v
    if length(v.namespaces) > 0 && can(regex(":user/", v.principal_arn))
  }
}

resource "aws_iam_policy" "ml_data_rw" {
  name        = "${var.cluster_name}-ml-data-rw"
  description = "Read/write access to ML data bucket for namespace-scoped users"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListAndLocation"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketMultipartUploads",
          "s3:ListBucketVersions",
        ]
        Resource = "arn:aws:s3:::${var.ml_data_bucket_name}"
      },
      {
        Sid    = "ObjectRW"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:AbortMultipartUpload",
          "s3:ListMultipartUploadParts",
        ]
        Resource = "arn:aws:s3:::${var.ml_data_bucket_name}/*"
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_user_policy_attachment" "ml_data_rw" {
  for_each = local.ml_ns_iam_users

  user       = regex(":user/(.+)$", each.value.principal_arn)[0]
  policy_arn = aws_iam_policy.ml_data_rw.arn
}

