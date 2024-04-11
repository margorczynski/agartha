locals {
  spark_namespace = "${var.kubernetes_processing_namespace_base}-spark"
  flink_namespace = "${var.kubernetes_processing_namespace_base}-flink"
  trino_namespace = "${var.kubernetes_processing_namespace_base}-trino"

  trino_additional_catalogs_config = {
    agartha = {
      connector = {
        name = "iceberg"
      }

      iceberg = {
        file-format = "PARQUET"

        catalog = {
          type = "nessie"
        }

        nessie-catalog = {
          uri = "http://nessie.lakehouse.svc.cluster.local:19120/api/v1/"
          default-warehouse-dir = "s3a://standardized/"
        }
      }

      hive = {
        s3 = {
          path-style-access = true
          ssl = {
            enabled = false
          }
          aws-access-key = "abc"
          aws-secret-key = "abc"
          endpoint = "abc"
        }
      }
    }
  }
}