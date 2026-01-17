"""
Spark job: Curate GitHub repositories with validation and enrichment.

This job reads from the raw Iceberg table, applies data quality rules,
and creates a curated table ready for analytics.
"""

import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col,
    coalesce,
    datediff,
    current_timestamp,
    lit,
    when,
)


def main():
    spark = get_spark_session()
    try:
        # Create namespace if not exists
        spark.sql("CREATE NAMESPACE IF NOT EXISTS agartha.curated")

        # Read from raw table
        raw_df = spark.table("agartha.raw.github_repositories")

        # Curate: filter, clean, and enrich
        curated_df = (
            raw_df
            # Filter out invalid records
            .filter(col("id").isNotNull())
            .filter(col("name").isNotNull())
            .filter(col("full_name").isNotNull())
            # Handle nulls with defaults
            .withColumn("description", coalesce(col("description"), lit("")))
            .withColumn("language", coalesce(col("language"), lit("Unknown")))
            .withColumn("license_name", coalesce(col("license_name"), lit("None")))
            # Add computed columns
            .withColumn(
                "days_since_push",
                datediff(current_timestamp(), col("pushed_at"))
            )
            .withColumn(
                "days_since_created",
                datediff(current_timestamp(), col("created_at"))
            )
            .withColumn(
                "activity_status",
                when(col("archived"), "archived")
                .when(datediff(current_timestamp(), col("pushed_at")) <= 30, "active")
                .when(datediff(current_timestamp(), col("pushed_at")) <= 180, "moderate")
                .otherwise("stale")
            )
            .withColumn(
                "popularity_score",
                col("stargazers_count") + col("forks_count") * 2
            )
        )

        # Write to Iceberg table
        curated_df.writeTo("agartha.curated.github_repositories").createOrReplace()

        raw_count = raw_df.count()
        curated_count = curated_df.count()
        print(f"SUCCESS: Curated {curated_count} repositories (from {raw_count} raw)")

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
