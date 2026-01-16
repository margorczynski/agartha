"""
Spark job: Clean and validate people data from raw layer.

This job is submitted via Spark Operator and orchestrated by Dagster.
"""

import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, initcap


def main():
    spark = get_spark_session()
    try:
        # Create namespace if not exists
        spark.sql("CREATE NAMESPACE IF NOT EXISTS agartha.curated")

        # Read from raw table
        raw_df = spark.table("agartha.raw.people")

        # Clean and validate
        curated_df = (
            raw_df.filter(col("first_name").isNotNull())
            .filter(col("last_name").isNotNull())
            .filter((col("age") >= 0) & (col("age") <= 120))
            .withColumn("first_name", initcap(col("first_name")))
            .withColumn("last_name", initcap(col("last_name")))
        )

        # Write to Iceberg table
        curated_df.writeTo("agartha.curated.people").createOrReplace()

        raw_count = raw_df.count()
        curated_count = curated_df.count()
        filtered_count = raw_count - curated_count
        print(f"SUCCESS: Curated {curated_count} rows (filtered {filtered_count})")

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
