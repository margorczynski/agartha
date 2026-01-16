# ConfigMap containing PySpark scripts for Spark Operator jobs
# These scripts are mounted in Spark driver/executor pods and executed via local:// paths

resource "kubernetes_config_map_v1" "spark_scripts" {
  metadata {
    name      = "dagster-spark-scripts"
    namespace = var.spark_namespace
    labels    = local.dagster_labels
  }

  data = {
    "raw_people.py"              = file("${path.module}/spark_jobs/raw_people.py")
    "curated_people.py"          = file("${path.module}/spark_jobs/curated_people.py")
    "people_age_distribution.py" = file("${path.module}/spark_jobs/people_age_distribution.py")
  }
}
