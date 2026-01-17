"""
Spark job: Ingest GitHub contributors from dlt Parquet files into Iceberg table.

This job reads Parquet files created by dlt and loads them into an Iceberg table
for further processing. Submitted via Spark Operator and orchestrated by Dagster.
"""

import sys
from pyspark.sql import SparkSession


def main():
    spark = get_spark_session()
    try:
        # Create namespace if not exists
        spark.sql("CREATE NAMESPACE IF NOT EXISTS agartha.raw")

        # Read dlt-created Parquet files from S3
        raw_df = spark.read.parquet("s3a://agartha-raw/github/contributors/")

        # Write to Iceberg table
        raw_df.writeTo("agartha.raw.github_contributors").createOrReplace()

        row_count = raw_df.count()
        print(f"SUCCESS: Wrote {row_count} contributors to agartha.raw.github_contributors")

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
