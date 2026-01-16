"""
Spark job: Compute age distribution statistics from curated people data.

This job is submitted via Spark Operator and orchestrated by Dagster.
"""

import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, count, when


def main():
    spark = get_spark_session()
    try:
        # Create namespace if not exists
        spark.sql("CREATE NAMESPACE IF NOT EXISTS agartha.analytics")

        # Read from curated table
        curated_df = spark.table("agartha.curated.people")

        # Compute age distribution
        age_dist_df = curated_df.select(
            when(col("age") < 18, "0-17")
            .when(col("age") < 30, "18-29")
            .when(col("age") < 45, "30-44")
            .when(col("age") < 60, "45-59")
            .otherwise("60+")
            .alias("age_group")
        ).groupBy("age_group").agg(count("*").alias("count"))

        # Write to Iceberg table
        age_dist_df.writeTo("agartha.analytics.people_age_distribution").createOrReplace()

        bucket_count = age_dist_df.count()
        print(f"SUCCESS: Created age distribution with {bucket_count} buckets")

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
