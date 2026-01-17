# ConfigMap containing PySpark scripts for Spark Operator jobs
# These scripts are mounted in Spark driver/executor pods and executed via local:// paths

resource "kubernetes_config_map_v1" "spark_scripts" {
  metadata {
    name      = "dagster-spark-scripts"
    namespace = var.spark_namespace
    labels    = local.dagster_labels
  }

  data = {
    # GitHub data pipeline: raw -> curated -> analytics
    "raw_github_repos.py"        = file("${path.module}/spark_jobs/raw_github_repos.py")
    "raw_github_contributors.py" = file("${path.module}/spark_jobs/raw_github_contributors.py")
    "curated_github_repos.py"    = file("${path.module}/spark_jobs/curated_github_repos.py")
    "github_repo_analytics.py"   = file("${path.module}/spark_jobs/github_repo_analytics.py")
  }
}
