# ─────────────────────────────────────────────────────────────────────────────
# EKS Access Entries — per-user/role IAM RBAC (no shared kubeconfig)
# ─────────────────────────────────────────────────────────────────────────────

locals {
  # Principals that are scoped to specific namespaces (team members, not admins).
  namespace_scoped = {
    for k, v in var.cluster_access : k => v
    if length(v.namespaces) > 0
  }

  # Split by principal type so we can use the correct attachment resource.
  ns_iam_users = {
    for k, v in local.namespace_scoped : k => v
    if can(regex(":user/", v.principal_arn))
  }
  ns_iam_roles = {
    for k, v in local.namespace_scoped : k => v
    if can(regex(":role/", v.principal_arn))
  }
}

# IAM policy — read/write access to the ML scripts bucket.
# Only created when at least one namespace-scoped principal exists and the
# bucket ARN has been provided.
resource "aws_iam_policy" "ns_users_s3_scripts" {
  count = length(local.namespace_scoped) > 0 && var.ml_scripts_bucket_arn != null ? 1 : 0

  name        = "${var.cluster_name}-ns-users-s3-scripts"
  description = "Grants namespace-scoped EKS users read/write access to the ML scripts bucket."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ObjectAccess"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload"]
        Resource = "${var.ml_scripts_bucket_arn}/*"
      },
      {
        Sid      = "BucketAccess"
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = var.ml_scripts_bucket_arn
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_user_policy_attachment" "ns_users_s3_scripts" {
  for_each = length(local.namespace_scoped) > 0 && var.ml_scripts_bucket_arn != null ? local.ns_iam_users : {}

  user       = regex("[^/]+$", each.value.principal_arn)
  policy_arn = aws_iam_policy.ns_users_s3_scripts[0].arn
}

resource "aws_iam_role_policy_attachment" "ns_users_s3_scripts" {
  for_each = length(local.namespace_scoped) > 0 && var.ml_scripts_bucket_arn != null ? local.ns_iam_roles : {}

  role       = regex("[^/]+$", each.value.principal_arn)
  policy_arn = aws_iam_policy.ns_users_s3_scripts[0].arn
}

resource "aws_eks_access_entry" "users" {
  for_each = var.cluster_access

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value.principal_arn
  type          = "STANDARD"

  tags = var.tags
}

resource "aws_eks_access_policy_association" "users" {
  for_each = var.cluster_access

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/${each.value.policy}"

  # Namespace-scoped when the caller specifies namespaces; cluster-wide otherwise.
  access_scope {
    type       = length(each.value.namespaces) > 0 ? "namespace" : "cluster"
    namespaces = length(each.value.namespaces) > 0 ? each.value.namespaces : null
  }

  depends_on = [aws_eks_access_entry.users]
}
