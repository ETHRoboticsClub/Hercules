# ─────────────────────────────────────────────────────────────────────────────
# Kubernetes RBAC extensions for namespace-scoped users
#
# AmazonEKSEditPolicy binds principals to the built-in 'edit' ClusterRole,
# which only covers core API resources. CRDs (TrainJob, etc.) must be
# aggregated in explicitly. The aggregate-to-edit/admin labels cause Kubernetes
# to automatically merge these rules into every existing and future binding of
# the 'edit' and 'admin' ClusterRoles — no per-user RoleBinding required.
# ─────────────────────────────────────────────────────────────────────────────

resource "kubernetes_cluster_role" "kubeflow_edit" {
  metadata {
    name = "kubeflow-trainjob-edit"
    labels = {
      "rbac.authorization.k8s.io/aggregate-to-edit"  = "true"
      "rbac.authorization.k8s.io/aggregate-to-admin" = "true"
    }
  }

  # Full CRUD on TrainJobs and namespace-scoped TrainingRuntimes
  rule {
    api_groups = ["kubeflow.org"]
    resources  = ["trainjobs", "trainjobs/status", "trainingruntimes", "trainingruntimes/status"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Read-only access to cluster-wide TrainingRuntimes (lists available presets)
  rule {
    api_groups = ["kubeflow.org"]
    resources  = ["clustertrainingruntimes"]
    verbs      = ["get", "list", "watch"]
  }

  depends_on = [module.eks_addons]
}
