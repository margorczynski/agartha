"""
Spark job: Compute GitHub repository analytics aggregations.

This job creates multiple analytics tables:
1. Language distribution across repositories
2. Repository activity summary
3. Top repositories by popularity
"""

import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col,
    count,
    sum as spark_sum,
    avg,
    max as spark_max,
    min as spark_min,
    desc,
)


def main():
    spark = get_spark_session()
    try:
        # Create namespace if not exists
        spark.sql("CREATE NAMESPACE IF NOT EXISTS agartha.analytics")

        # Read curated repositories
        repos_df = spark.table("agartha.curated.github_repositories")

        # 1. Language distribution
        language_dist_df = (
            repos_df.groupBy("language")
            .agg(
                count("*").alias("repo_count"),
                spark_sum("stargazers_count").alias("total_stars"),
                spark_sum("forks_count").alias("total_forks"),
                avg("popularity_score").alias("avg_popularity"),
            )
            .orderBy(desc("repo_count"))
        )
        language_dist_df.writeTo("agartha.analytics.github_language_stats").createOrReplace()
        print(f"Created language stats with {language_dist_df.count()} languages")

        # 2. Activity summary by status
        activity_df = (
            repos_df.groupBy("activity_status")
            .agg(
                count("*").alias("repo_count"),
                avg("days_since_push").alias("avg_days_since_push"),
                spark_sum("open_issues_count").alias("total_open_issues"),
            )
            .orderBy("activity_status")
        )
        activity_df.writeTo("agartha.analytics.github_activity_summary").createOrReplace()
        print(f"Created activity summary with {activity_df.count()} statuses")

        # 3. Overall organization summary (single row)
        summary_df = repos_df.agg(
            count("*").alias("total_repos"),
            spark_sum("stargazers_count").alias("total_stars"),
            spark_sum("forks_count").alias("total_forks"),
            spark_sum("open_issues_count").alias("total_open_issues"),
            avg("popularity_score").alias("avg_popularity"),
            spark_max("stargazers_count").alias("max_stars"),
            spark_min("created_at").alias("oldest_repo_date"),
            spark_max("pushed_at").alias("latest_push_date"),
        )
        summary_df.writeTo("agartha.analytics.github_org_summary").createOrReplace()
        print("Created organization summary")

        print("SUCCESS: All analytics tables created")

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
