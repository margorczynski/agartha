"""
Spark job: Ingest raw people data from S3 text files into Iceberg table.

This job is submitted via Spark Operator and orchestrated by Dagster.
"""

import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, split, trim


def main():
    spark = get_spark_session()
    try:
        # Create namespace if not exists
        spark.sql("CREATE NAMESPACE IF NOT EXISTS agartha.raw")

        # Read raw text file
        raw_df = spark.read.text("s3a://agartha-raw/people.txt")

        # Parse pipe-delimited data
        parsed_df = raw_df.select(
            trim(split(col("value"), "\\|").getItem(0)).alias("first_name"),
            trim(split(col("value"), "\\|").getItem(1)).alias("last_name"),
            trim(split(col("value"), "\\|").getItem(2)).cast("int").alias("age"),
        )

        # Write to Iceberg table
        parsed_df.writeTo("agartha.raw.people").createOrReplace()

        row_count = parsed_df.count()
        print(f"SUCCESS: Wrote {row_count} rows to agartha.raw.people")

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
