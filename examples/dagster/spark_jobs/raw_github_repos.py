"""
Spark job: Ingest GitHub repositories from dlt Parquet files into Iceberg table.

This job reads Parquet files created by dlt and loads them into an Iceberg table
for further processing. Submitted via Spark Operator and orchestrated by Dagster.
"""

import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, to_timestamp


def main():
    spark = get_spark_session()
    try:
        # Create namespace if not exists
        spark.sql("CREATE NAMESPACE IF NOT EXISTS agartha.raw")

        # Read dlt-created Parquet files from S3
        # dlt writes to: s3://bucket/dataset_name/table_name/
        raw_df = spark.read.parquet("s3a://agartha-raw/github/repositories/")

        # Convert timestamp strings to proper timestamps
        processed_df = (
            raw_df.withColumn("created_at", to_timestamp(col("created_at")))
            .withColumn("updated_at", to_timestamp(col("updated_at")))
            .withColumn("pushed_at", to_timestamp(col("pushed_at")))
        )

        # Write to Iceberg table
        processed_df.writeTo("agartha.raw.github_repositories").createOrReplace()

        row_count = processed_df.count()
        print(f"SUCCESS: Wrote {row_count} repositories to agartha.raw.github_repositories")

    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        spark.stop()


def get_spark_session() -> SparkSession:
    """Get the existing SparkSession (created by spark-submit with all config)."""
    return SparkSession.builder.getOrCreate()


if __name__ == "__main__":
    main()
